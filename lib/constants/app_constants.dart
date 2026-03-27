/// App-wide constants for SmartCity
class AppConstants {
  AppConstants._();

  // Issue categories with keywords for auto-detection
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'garbage',
      'label': 'Garbage / Waste',
      'icon': '🗑️',
      'keywords': [
        'garbage',
        'waste',
        'trash',
        'litter',
        'dumping',
        'dirty',
        'smell',
        'filth'
      ],
    },
    {
      'id': 'water',
      'label': 'Water / Drainage',
      'icon': '💧',
      'keywords': [
        'water',
        'pipe',
        'leak',
        'flood',
        'drain',
        'sewage',
        'overflow',
        'tap',
        'supply'
      ],
    },
    {
      'id': 'road',
      'label': 'Road / Pothole',
      'icon': '🛣️',
      'keywords': [
        'road',
        'pothole',
        'crack',
        'broken',
        'path',
        'street',
        'highway',
        'footpath'
      ],
    },
    {
      'id': 'electricity',
      'label': 'Electricity',
      'icon': '⚡',
      'keywords': [
        'electric',
        'light',
        'power',
        'wire',
        'pole',
        'streetlight',
        'outage',
        'voltage'
      ],
    },
    {
      'id': 'tree',
      'label': 'Fallen Tree',
      'icon': '🌳',
      'keywords': ['tree', 'branch', 'fallen', 'block', 'uprooted'],
    },
    {
      'id': 'other',
      'label': 'Other',
      'icon': '📌',
      'keywords': [],
    },
  ];

  // Indian cities for leaderboard demo
  static const List<String> cities = [
    'Mumbai',
    'Delhi',
    'Bengaluru',
    'Chennai',
    'Hyderabad',
    'Pune',
    'Nashik',
    'Kolkata',
    'Ahmedabad',
    'Jaipur',
  ];

  // Issue status options
  static const String statusPending = 'pending';
  static const String statusInProgress = 'in_progress';
  static const String statusResolved = 'resolved';

  // Chatbot predefined Q&A
  static const List<Map<String, String>> chatbotQA = [
    {
      'trigger': 'hello|hi|hey|start',
      'response':
          'Hello! 👋 I am SmartCity Assistant. I can help you report civic issues. What problem are you facing?',
    },
    {
      'trigger': 'garbage|waste|trash|litter',
      'response':
          '🗑️ I detected a **Garbage/Waste** issue. Tap "Use This Category" to auto-fill the report form. Please also attach a photo of the issue.',
      'category': 'garbage',
    },
    {
      'trigger': 'water|pipe|leak|drain|sewage|flood',
      'response':
          '💧 This looks like a **Water/Drainage** issue. Tap "Use This Category" to start reporting. Include your location for faster resolution.',
      'category': 'water',
    },
    {
      'trigger': 'road|pothole|broken|crack|street',
      'response':
          '🛣️ I\'ve identified a **Road/Pothole** issue. Tap "Use This Category" to report it. Photos are mandatory for road issues.',
      'category': 'road',
    },
    {
      'trigger': 'electric|light|power|wire|pole|streetlight',
      'response':
          '⚡ This seems like an **Electricity** issue. If it\'s a live wire emergency, please call 1912 immediately! Otherwise tap "Use This Category".',
      'category': 'electricity',
    },
    {
      'trigger': 'emergency|urgent|danger|accident',
      'response':
          '🚨 This sounds urgent! Please enable **Emergency Mode** when submitting your report for priority handling. Do you need police (100), ambulance (108), or fire (101)?',
    },
    {
      'trigger': 'how|report|submit|complain',
      'response':
          '📝 To report an issue:\n1. Tap the "+" button\n2. Take a photo\n3. Your location is auto-detected\n4. Select a category\n5. Submit!\n\nWould you like to start reporting now?',
    },
    {
      'trigger': 'anonymous|hide|identity|private',
      'response':
          '🕵️ Yes! You can report anonymously. Just toggle the "Report Anonymously" switch on the report screen. Your identity will be hidden from public view.',
    },
    {
      'trigger': 'status|progress|update|resolve',
      'response':
          '📊 You can check the status of your complaints on the Map screen. Issues show as:\n🔴 Red = Pending\n🟡 Yellow = In Progress\n🟢 Green = Resolved',
    },
    {
      'trigger': 'vote|upvote|priority|rank',
      'response':
          '👍 You can vote on issues to increase their priority! Your voting weight is based on your trust score. Higher trust = more impact on priority.',
    },
    {
      'trigger': 'tree|fallen|uprooted|branch',
      'response':
          '🌳 A fallen tree is a safety hazard! I\'ll categorize this as **Fallen Tree**. If it\'s blocking a road, please also call municipal helpline 1800-XXX-XXXX.',
      'category': 'tree',
    },
    {
      'trigger': 'thank|thanks|bye|goodbye',
      'response':
          '😊 You\'re welcome! Together we can make our city better. Feel free to ask anything anytime!',
    },
  ];

  // Dummy user IDs for demo (replace with real auth)
  static const String dummyUserId = 'user_demo_001';
  static const String dummyUserName = 'Demo Citizen';
  static const double defaultTrustScore = 1.0;

  // Priority calculation weights
  static const double emergencyBoost = 50.0;
  static const double baseVoteWeight = 1.0;
}
