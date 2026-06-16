/// Declare strings as StringLocale objects. Importing this registers them.
import 'package:stringlocale/stringlocale.dart';

final welcome = StringLocale('Welcome to xChangeBazar', id: 'welcome');

final campaignCount = StringLocale(
  'You have {count} active campaigns',
  id: 'campaign_count',
  params: {'count': Param.plural()},
);

final listing = StringLocale(
  '{creator} charges {amount}, status {status}, deliver by {date}',
  id: 'listing',
  params: {
    'creator': Param.literal(),
    'amount': Param.currency('NPR'),
    'status': Param.translatable(['approved', 'pending', 'rejected']),
    'date': Param.date('long'),
  },
);

final greeting = StringLocale(
  '{name} hello. she has {count} posts. status is {status}',
  id: 'greeting',
  params: {
    'name': Param.literal(),
    'count': Param.plural(),
    'status': Param.translatable(['approved', 'pending']),
  },
  gendered: true,
);

final allStrings = [welcome, campaignCount, listing, greeting];

/// Force lazy top-level finals to initialize (and thus auto-register).
/// Call this once before compile/resolve. Returns the count registered.
int registerAll() => allStrings.length;
