import '../../domain/models/chat_message.dart';

const List<ChatMessage> kMockChat = [
  ChatMessage(
    id: '1',
    author: ChatAuthor.bot,
    text: 'Hola Juan, puedo ayudarte con consejos sobre riego, '
        'plagas o clima. ¿Qué necesitas saber hoy?',
    time: '10:42 AM',
  ),
  ChatMessage(
    id: '2',
    author: ChatAuthor.user,
    text: 'Necesito revisar el pronóstico para la cosecha de '
        'banano en Magdalena.',
    time: '10:43 AM',
  ),
  ChatMessage(
    id: '3',
    author: ChatAuthor.bot,
    text: 'Entendido. Según los datos del satélite, se esperan '
        'lluvias moderadas en la Zona Bananera en las próximas '
        '48 horas. Te recomiendo asegurar el drenaje.',
    time: '10:44 AM',
    attachmentTitle: 'Pronóstico Magdalena',
    attachmentSubtitle: 'Lluvias: 85% probabilidad',
  ),
];

const List<String> kChatSuggestions = [
  '¿Cuándo regar?',
  'Estado del clima',
  'Control de plagas',
];
