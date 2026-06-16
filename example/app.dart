/// Use it — load once, set the locale, resolve each StringLocale.
import 'package:stringlocale/stringlocale.dart';

import 'strings.dart';

void main() {
  registerAll();

  load('dist'); // dart:io-backed loader
  setLocale('ne-NP'); // the user's language

  print(welcome.resolve());
  print(campaignCount.resolve(args: {'count': 12}));
  print(listing.resolve(args: {
    'creator': 'Anisha',
    'amount': 2500,
    'status': 'pending',
    'date': '2025-02-15',
  }));
  print(greeting.resolve(args: {
    'name': 'साजन',
    'count': 2,
    'status': 'approved',
    'gender': 'male',
  }));
}
