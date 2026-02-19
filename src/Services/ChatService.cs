using Azure.AI.Inference;
using Azure.Identity;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly ChatCompletionsClient _client;
        private readonly string _modelDeploymentName;
        private readonly ILogger<ChatService> _logger;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger)
        {
            _logger = logger;

            var endpoint = configuration["AzureAI:Endpoint"]
                ?? throw new InvalidOperationException("AzureAI:Endpoint configuration is required.");
            _modelDeploymentName = configuration["AzureAI:ModelDeploymentName"] ?? "phi-4";

            _client = new ChatCompletionsClient(
                new Uri(endpoint),
                new DefaultAzureCredential());
        }

        public async Task<string> GetChatResponseAsync(List<ChatMessage> conversationHistory)
        {
            try
            {
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
