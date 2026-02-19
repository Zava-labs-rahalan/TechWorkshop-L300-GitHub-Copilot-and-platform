using Azure.AI.ContentSafety;
using Azure.AI.Inference;
using Azure.Core;
using Azure.Identity;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    /// <summary>
    /// Wraps a TokenCredential to override the requested scope.
    /// The Azure.AI.Inference SDK (beta) requests tokens with scope "https://ml.azure.com/.default",
    /// but the Azure AI Services endpoint requires "https://cognitiveservices.azure.com/.default".
    /// </summary>
    internal sealed class CognitiveServicesCredential : TokenCredential
    {
        private static readonly string[] Scopes = ["https://cognitiveservices.azure.com/.default"];
        private readonly TokenCredential _inner;

        public CognitiveServicesCredential(TokenCredential inner) => _inner = inner;

        public override AccessToken GetToken(TokenRequestContext requestContext, CancellationToken cancellationToken)
            => _inner.GetToken(new TokenRequestContext(Scopes), cancellationToken);

        public override ValueTask<AccessToken> GetTokenAsync(TokenRequestContext requestContext, CancellationToken cancellationToken)
            => _inner.GetTokenAsync(new TokenRequestContext(Scopes), cancellationToken);
    }

    public class ChatService
    {
        private readonly ChatCompletionsClient _client;
        private readonly ContentSafetyClient _contentSafetyClient;
        private readonly string _modelDeploymentName;
        private readonly ILogger<ChatService> _logger;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger)
        {
            _logger = logger;

            var endpoint = configuration["AzureAI:Endpoint"]
                ?? throw new InvalidOperationException("AzureAI:Endpoint configuration is required.");
            _modelDeploymentName = configuration["AzureAI:ModelDeploymentName"] ?? "phi-4";

            var credential = new CognitiveServicesCredential(new DefaultAzureCredential());

            _client = new ChatCompletionsClient(
                new Uri(endpoint),
                credential);

            var contentSafetyEndpoint = configuration["AzureAI:ContentSafetyEndpoint"]
                ?? throw new InvalidOperationException("AzureAI:ContentSafetyEndpoint configuration is required.");
            _contentSafetyClient = new ContentSafetyClient(
                new Uri(contentSafetyEndpoint),
                new DefaultAzureCredential());
        }

        /// <summary>
        /// Evaluates the given text against Azure AI Content Safety.
        /// Returns (isSafe, message) where message contains details when unsafe.
        /// </summary>
        private async Task<(bool IsSafe, string? Reason)> EvaluateContentSafetyAsync(string text)
        {
            try
            {
                var request = new AnalyzeTextOptions(text);

                var response = await _contentSafetyClient.AnalyzeTextAsync(request);

                const int threshold = 2;

                var categories = new (string Name, int? Severity)[]
                {
                    ("Violence",      response.Value.CategoriesAnalysis.FirstOrDefault(c => c.Category == TextCategory.Violence)?.Severity),
                    ("Sexual",        response.Value.CategoriesAnalysis.FirstOrDefault(c => c.Category == TextCategory.Sexual)?.Severity),
                    ("Hate",          response.Value.CategoriesAnalysis.FirstOrDefault(c => c.Category == TextCategory.Hate)?.Severity),
                    ("SelfHarm",      response.Value.CategoriesAnalysis.FirstOrDefault(c => c.Category == TextCategory.SelfHarm)?.Severity),
                };

                foreach (var (name, severity) in categories)
                {
                    _logger.LogInformation("Content Safety — {Category}: {Severity}", name, severity ?? 0);
                    if (severity.HasValue && severity.Value >= threshold)
                    {
                        _logger.LogWarning("Content Safety blocked message. Category={Category}, Severity={Severity}", name, severity.Value);
                        return (false, name);
                    }
                }

                _logger.LogInformation("Content Safety evaluation passed.");
                return (true, null);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error calling Azure AI Content Safety. Blocking request as a precaution.");
                return (false, "ServiceError");
            }
        }

        public async Task<string> GetChatResponseAsync(List<ChatMessage> conversationHistory)
        {
            try
            {
                // Evaluate the latest user message with Content Safety
                var latestUserMessage = conversationHistory.LastOrDefault(m => m.Role == "user")?.Content;
                if (!string.IsNullOrEmpty(latestUserMessage))
                {
                    var (isSafe, reason) = await EvaluateContentSafetyAsync(latestUserMessage);
                    if (!isSafe)
                    {
                        return "I'm sorry, but I'm unable to process that message as it may contain inappropriate content. Please rephrase your question and try again.";
                    }
                }

                var requestOptions = new ChatCompletionsOptions
                {
                    Model = _modelDeploymentName
                };

                requestOptions.Messages.Add(new ChatRequestSystemMessage(
                    "You are a helpful assistant for the Zava Storefront. " +
                    "You can answer questions about products, pricing, and general inquiries. " +
                    "Be friendly and concise."));

                foreach (var message in conversationHistory)
                {
                    if (message.Role == "user")
                        requestOptions.Messages.Add(new ChatRequestUserMessage(message.Content));
                    else if (message.Role == "assistant")
                        requestOptions.Messages.Add(new ChatRequestAssistantMessage(message.Content));
                }

                var response = await _client.CompleteAsync(requestOptions);
                return response.Value.Content;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting chat response from AI service");
                return "I'm sorry, I encountered an error processing your request. Please try again later.";
            }
        }
    }
}
