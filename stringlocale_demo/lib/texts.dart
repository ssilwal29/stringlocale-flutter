import 'package:stringlocale/stringlocale.dart';

// ── Static strings ────────────────────────────────────────────────────────────

final welcome = staticText('welcome', 'Welcome to stringlocale');
final signIn = staticText('sign_in', 'Sign in');
final signOut = staticText('sign_out', 'Sign out');
final loading = staticText('loading', 'Loading...');
final errorGeneric = staticText(
  'error_generic',
  'Something went wrong. Please try again.',
);

// ── Dynamic strings ───────────────────────────────────────────────────────────

final websitePlanPrice = dynamicText(
  'website_plan_price',
  '{owner}\'s website plan costs {amount} per month',
  {
    'owner': ParamKind.literal,
    'amount': const Param('amount', kind: ParamKind.currency, currency: 'NPR'),
  },
);

final websiteStatus = dynamicText(
  'website_status',
  'Website status: {status}',
  {'status': ParamKind.literal},
);

final websiteAudience = dynamicText(
  'website_audience',
  '{owner}\'s website supports visitors in {region}',
  {
    'owner': ParamKind.literal,
    'region': const Param(
      'region',
      kind: ParamKind.translatable,
      context: 'website visitor region',
    ),
  },
);

final launchDate = dynamicText('launch_date', 'Launch by {date}', {
  'date': ParamKind.date,
});

final updatedRelative = dynamicText('updated_relative', 'Updated {when}', {
  'when': ParamKind.relative,
});

// ── Plural strings ────────────────────────────────────────────────────────────

final pageCount = pluralText(
  'page_count',
  'You have {count} localized page',
  'You have {count} localized pages',
);

final localizedPageCount = pluralText(
  'localized_page_count',
  '{owner}\'s website has {pages} localized page ready for {amount}',
  '{owner}\'s website has {pages} localized pages ready for {amount}',
  countParam: 'pages',
  params: {
    'owner': ParamKind.literal,
    'amount': const Param('amount', kind: ParamKind.currency, currency: 'NPR'),
  },
);

// ── User-authored / adapted ───────────────────────────────────────────────────

final websiteNote = dynamicText('website_note', 'Note: {brief}', {
  'brief': ParamKind.user,
});

final websiteSummary = dynamicText('website_summary', 'Summary: {summary}', {
  'summary': const Param('summary', kind: ParamKind.userAdapted),
});

final texts = <Message>[
  welcome,
  signIn,
  signOut,
  loading,
  errorGeneric,
  websitePlanPrice,
  websiteStatus,
  websiteAudience,
  launchDate,
  updatedRelative,
  pageCount,
  localizedPageCount,
  websiteNote,
  websiteSummary,
];
