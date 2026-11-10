import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'production_repository.dart';

final productionRepoProvider = Provider<ProductionRepository>(
  (ref) => ProductionRepository(ref.watch(supabaseProvider)),
);