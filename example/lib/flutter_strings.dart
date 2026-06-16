import 'package:stringlocale/stringlocale.dart';

final appTitle = StringLocale(
  'Creator orders',
  id: 'flutter_sample.title',
);

final orderSummary = StringLocale(
  '{name} has {count} {status} orders totaling {total}',
  id: 'flutter_sample.order_summary',
  params: {
    'name': Param.literal(),
    'count': Param.plural(),
    'status': Param.translatable(['approved', 'pending', 'rejected']),
    'total': Param.currency('NPR'),
  },
);

final nextPayout = StringLocale(
  'Next payout arrives on {date}',
  id: 'flutter_sample.next_payout',
  params: {
    'date': Param.date('long'),
  },
);

final audienceMessage = StringLocale(
  '{name}, your {tier} workspace is ready',
  id: 'flutter_sample.audience_message',
  params: {
    'name': Param.literal(),
    'tier': Param.translatable(['standard', 'gold'], inline: true),
  },
  axes: const {
    'audience': ['buyer', 'seller'],
  },
  required: const ['audience'],
);

final snackbarLabel = StringLocale(
  'Saved locale {locale}',
  id: 'flutter_sample.snackbar',
  params: {
    'locale': Param.literal(),
  },
);

final userAdaptedPreview = StringLocale(
  'Shopper preview: {note}',
  id: 'flutter_sample.user_adapted_preview',
  params: {
    'note': Param.userAdapted(
      context: 'Friendly short note shown to shoppers in product cards',
    ),
  },
);

final flutterSampleStrings = [
  appTitle,
  orderSummary,
  nextPayout,
  audienceMessage,
  snackbarLabel,
  userAdaptedPreview,
];

int registerFlutterSampleStrings() => flutterSampleStrings.length;
