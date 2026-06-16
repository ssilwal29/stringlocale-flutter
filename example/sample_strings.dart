/// Strings used by example/main.dart.
import 'package:stringlocale/stringlocale.dart';

final dashboardTitle = StringLocale(
  'Creator campaign dashboard',
  id: 'sample.dashboard_title',
);

final campaignSummary = StringLocale(
  '{creator} has {count} {status} campaigns worth {budget}, due {dueDate}',
  id: 'sample.campaign_summary',
  params: {
    'creator': Param.literal(),
    'count': Param.plural(),
    'status': Param.translatable(['approved', 'pending', 'rejected']),
    'budget': Param.currency('NPR'),
    'dueDate': Param.date('long'),
  },
);

final audienceCta = StringLocale(
  '{name}, your {tier} campaign is {status}',
  id: 'sample.audience_cta',
  params: {
    'name': Param.literal(),
    'tier':
        Param.translatable(['standard', 'gold', 'enterprise'], inline: true),
    'status': Param.translatable(['approved', 'pending', 'rejected']),
  },
  axes: const {
    'audience': ['buyer', 'seller'],
  },
  required: const ['audience'],
);

final creatorGreeting = StringLocale(
  '{name} has {count} saved campaigns',
  id: 'sample.creator_greeting',
  params: {
    'name': Param.literal(),
    'count': Param.plural(),
  },
  gendered: true,
);

final metricLine = StringLocale(
  'Views: {views}; last updated {updated}',
  id: 'sample.metric_line',
  params: {
    'views': Param.number(),
    'updated': Param.relative(),
  },
);

final internalNote = StringLocale(
  'Internal note: {note}',
  id: 'sample.internal_note',
  params: {
    'note': Param.user(),
  },
);

final profileBio = StringLocale(
  'Creator bio: {bio}',
  id: 'sample.profile_bio',
  params: {
    'bio':
        Param.userAdapted(context: 'Short creator profile shown to shoppers'),
  },
);

final deliveryNote = StringLocale(
  'Delivery note for customers: {note}',
  id: 'sample.delivery_note',
  params: {
    'note': Param.userAdapted(
      context:
          'Keep shipping facts exact, but rewrite tone to sound warm and concise',
    ),
  },
);

final moderationReason = StringLocale(
  'Moderation summary: {reason}',
  id: 'sample.moderation_reason',
  params: {
    'reason': Param.userAdapted(),
  },
);

final sampleStrings = [
  dashboardTitle,
  campaignSummary,
  audienceCta,
  creatorGreeting,
  metricLine,
  internalNote,
  profileBio,
  deliveryNote,
  moderationReason,
];

/// Force lazy top-level finals to initialize and auto-register.
int sampleRegisterAll() => sampleStrings.length;
