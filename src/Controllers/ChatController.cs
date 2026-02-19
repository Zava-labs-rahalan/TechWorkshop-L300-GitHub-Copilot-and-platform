using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers
{
    public class ChatController : Controller
    {
        private readonly ChatService _chatService;
        private readonly ILogger<ChatController> _logger;
        private const string ChatSessionKey = "ChatHistory";

        public ChatController(ChatService chatService, ILogger<ChatController> logger)
        {
            _chatService = chatService;
            _logger = logger;
        }

        public IActionResult Index()
        {
            var viewModel = new ChatViewModel
            {
                Messages = GetChatHistory()
            };
            return View(viewModel);
        }

        [HttpPost]
        public async Task<IActionResult> SendMessage(string userMessage)
        {
            if (string.IsNullOrWhiteSpace(userMessage))
            {
                return RedirectToAction("Index");
            }

            _logger.LogInformation("User sent chat message: {MessagePreview}",
                userMessage.Length > 50 ? userMessage[..50] + "..." : userMessage);

            var chatHistory = GetChatHistory();

            chatHistory.Add(new ChatMessage { Role = "user", Content = userMessage });

            var response = await _chatService.GetChatResponseAsync(chatHistory);

            chatHistory.Add(new ChatMessage { Role = "assistant", Content = response });

            SaveChatHistory(chatHistory);

            var viewModel = new ChatViewModel
            {
                Messages = chatHistory
            };

            return View("Index", viewModel);
        }

        [HttpPost]
        public IActionResult Clear()
        {
            HttpContext.Session.Remove(ChatSessionKey);
            return RedirectToAction("Index");
        }

        private List<ChatMessage> GetChatHistory()
        {
            var json = HttpContext.Session.GetString(ChatSessionKey);
            if (string.IsNullOrEmpty(json))
                return new List<ChatMessage>();

            return System.Text.Json.JsonSerializer.Deserialize<List<ChatMessage>>(json)
                ?? new List<ChatMessage>();
        }

        private void SaveChatHistory(List<ChatMessage> messages)
        {
            var json = System.Text.Json.JsonSerializer.Serialize(messages);
            HttpContext.Session.SetString(ChatSessionKey, json);
        }
    }
}
