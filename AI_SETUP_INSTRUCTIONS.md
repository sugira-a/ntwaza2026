# Ntwaza AI Assistant Setup Instructions

## Overview
The AI Assistant feature has been successfully implemented with the following improvements:

### ✅ What's New:

1. **Draggable AI Icon** 
   - AI assistant icon is now draggable - users can position it anywhere on the screen
   - Beautiful gradient design with pulse animation
   - Tap to open the AI chat interface

2. **Enhanced Chat UI**
   - Modern, polished design with gradients and shadows
   - Smooth animations and transitions
   - Quick action chips for common questions
   - Improved message bubbles with better spacing

3. **Smart AI Context**
   - AI now knows about Ntwaza business
   - Can answer questions about delivery, payments, vendors
   - Provides budget-friendly shopping advice
   - Suggests meal plans and product substitutions
   - Understands Rwandan context and currency

## 🚀 Setup Instructions

### Step 1: Get a Free Google Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click **"Get API Key"** or **"Create API Key"**
4. Copy the generated API key

### Step 2: Configure the Backend

1. Open the file: `ntwaza-backend/.env`
2. Find the line that says:
   ```
   GEMINI_API_KEY=your-gemini-api-key-here
   ```
3. Replace `your-gemini-api-key-here` with your actual API key:
   ```
    GEMINI_API_KEY=your-actual-gemini-key-here
   ```

### Step 3: Restart the Backend Server

If your backend server is running, restart it to load the new environment variable:

```bash
cd ntwaza-backend
python run.py
```

### Step 4: Test the AI Assistant

1. Launch the Flutter app
2. You'll see a draggable AI icon on the home screen
3. Drag it to your preferred position
4. Tap the icon to open the AI chat
5. Try asking questions like:
   - "Plan meals under 15000 RWF"
   - "Find cheaper substitutes"
   - "What is Ntwaza?"
   - "How does delivery work?"

## 🎨 Features

### Draggable Icon
- **Position**: Starts at top-left, can be moved anywhere
- **Visual**: Green gradient with pulse indicator
- **Interaction**: Drag to move, tap to chat

### Chat Interface
- **Quick Actions**: Pre-defined questions for quick access
- **Smart Responses**: Context-aware AI that knows about Ntwaza
- **Beautiful Design**: Modern UI with gradients, shadows, and animations
- **Message Types**: 
  - User messages: Green gradient bubbles
  - AI responses: Themed bubbles with smooth styling
  - Loading states: Animated "Thinking..." indicator

### AI Capabilities
The AI assistant can help with:
- Budget-friendly meal planning
- Product substitutions to save money
- Monthly spending insights
- Healthy alternatives and dietary needs
- Questions about Ntwaza services
- Delivery information
- Payment options
- Vendor selection

## 📝 Notes

- The Gemini API has a generous free tier (15 requests/minute)
- The AI uses the `gemini-1.5-flash` model for fast responses
- Context is preserved within each chat session
- The AI is instructed to be helpful, friendly, and culturally aware

## 🔧 Troubleshooting

### "AI service request failed" Error
- Make sure you've added the GEMINI_API_KEY to the `.env` file
- Restart the backend server after adding the key
- Check that your API key is valid
- Ensure you have internet connection

### Draggable Icon Not Showing
- Make sure you're on the customer home screen
- Check that the Flutter app has been rebuilt after the code changes

### Chat Not Opening
- Verify the AI route is properly registered in the app router
- Check console for any error messages

## 🌟 Next Steps

You can further customize:
- Initial AI greeting message
- Quick action chips
- Draggable icon position and appearance
- Chat UI colors and styling
- AI personality and responses

Enjoy your new AI-powered shopping assistant! 🤖✨
