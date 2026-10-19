import '../entities/family_link_code.dart';

abstract interface class FamilyLinkCodeRepository {
  Future<FamilyLinkCode> fetch();
}
