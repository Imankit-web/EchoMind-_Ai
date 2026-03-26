class ConversationMemory {
  static String lastQuestion = '';
  static String lastAnswer = '';

  static void saveInteraction(String question, String answer) {
    lastQuestion = question;
    lastAnswer = answer;
  }

  static void clear() {
    lastQuestion = '';
    lastAnswer = '';
  }

  static bool get hasContext => lastQuestion.isNotEmpty && lastAnswer.isNotEmpty;
}
