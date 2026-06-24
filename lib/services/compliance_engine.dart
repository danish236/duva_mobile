class ComplianceEngine {
  // POCSO & Age Compliance
  static const int minAge = 18;
  
  static bool isUserEligible(DateTime dob) {
    final now = DateTime.now();
    final adultDate = DateTime(dob.year + minAge, dob.month, dob.day);
    return now.isAfter(adultDate);
  }

  // Legal Content Registry
  static Map<String, String> getLegalDocument(String docType) {
    switch (docType) {
      case 'terms':
        return {
          'title': 'TERMS OF SERVICE',
          'content': 'By using Duva, you agree to our terms. You must be at least 18 years of age. You agree not to use this platform for any illegal activities or harassment...'
        };
      case 'privacy':
        return {
          'title': 'PRIVACY POLICY',
          'content': 'Your data is encrypted. We collect location data only to provide alignment services. We comply with the Digital Personal Data Protection Act (DPDP)...'
        };
      case 'safety':
        return {
          'title': 'SAFETY GUIDELINES',
          'content': 'Duva has zero tolerance for any form of harassment. Any report of child abuse or non-consensual behavior is strictly reported to authorities under POCSO Act guidelines...'
        };
      default:
        return {'title': 'INFO', 'content': 'No content available.'};
    }
  }
}