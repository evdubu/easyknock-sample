@isTest
public class ContractsEmailServiceTest {
	@testSetup
	static void setupData() {
		Account acc = DataFactory.generateSingleAccount();
		insert acc;

		List<SAGE_Billing_Details__c> bes = new List<SAGE_Billing_Details__c>();

		SAGE_Billing_Details__c be = DataFactory.generateSingleBillingEntity();
		be.Billing_Account__c = acc.Id;
		bes.add(be);

		SAGE_Billing_Details__c devBe = DataFactory.generateSingleBillingEntity();
		devBe.Billing_Account__c = acc.Id;
		devBe.LOB__c = LineOfBusinessService.LOB_DEVELOPER;
		bes.add(devBe);
		insert bes;

		Agent_ID__c pe = DataFactory.generateSingleAgentID();
		pe.Account__c = acc.Id;
		insert pe;

		Opportunity opp = DataFactory.generateSingleOpportunity(acc.Id);
		opp.Provisioning_Entity__c = pe.Id;
		opp.Billing_Entity__c = be.Id;
		opp.Type = 'Downgrade';
		opp.RecordTypeId = Opportunities.RECORD_TYPES.get(
			Opportunities.RECORD_TYPE_RESI
		);

		Opportunity commercialOpp = DataFactory.generateSingleOpportunity(acc.Id);
		commercialOpp.Type = 'New';
		commercialOpp.RecordTypeId = Opportunities.RECORD_TYPES.get(
			Opportunities.RECORD_TYPE_COMMERCIAL
		);

		Opportunity commercialOppDepth = DataFactory.generateSingleOpportunity(
			acc.Id
		);
		commercialOppDepth.Provisioning_Entity__c = pe.Id;
		commercialOppDepth.Billing_Entity__c = bes[0].Id;
		commercialOppDepth.Type = 'New';
		commercialOppDepth.RecordTypeId = Opportunities.RECORD_TYPES.get(
			Opportunities.RECORD_TYPE_COMMERCIAL
		);

		Opportunity commercialOppAmax = DataFactory.generateSingleOpportunity(
			acc.Id
		);
		commercialOppAmax.Provisioning_Entity__c = pe.Id;
		commercialOppAmax.Billing_Entity__c = bes[0].Id;
		commercialOppAmax.Type = 'New';
		commercialOppAmax.RecordTypeId = Opportunities.RECORD_TYPES.get(
			Opportunities.RECORD_TYPE_COMMERCIAL
		);

		Opportunity devOpp = DataFactory.generateSingleOpportunity(acc.Id);
		devOpp.Billing_Entity__c = bes[1].Id;
		devOpp.Type = 'New';
		devOpp.RecordTypeId = Opportunities.RECORD_TYPES.get(
			Opportunities.RECORD_TYPE_DEVELOPER
		);

		List<Opportunity> opps = new List<Opportunity>{
			opp,
			commercialOpp,
			commercialOppDepth,
			commercialOppAmax,
			devOpp
		};
		insert opps;

		List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();

		SBQQ__Quote__c resiQuote = DataFactory.generateSingleQuote(opps[0].Id);
		resiQuote.Proposal_Id__c = 'Test';
		quotes.add(resiQuote);

		SBQQ__Quote__c commercialQuote = DataFactory.generateSingleQuote(
			opps[2].Id
		);
		commercialQuote.Proposal_Id__c = 'Test';
		quotes.add(commercialQuote);

		SBQQ__Quote__c commercialQuoteAmax = DataFactory.generateSingleQuote(
			opps[3].Id
		);
		commercialQuoteAmax.Proposal_Id__c = 'Test';
		quotes.add(commercialQuoteAmax);
		insert quotes;

		Product2 promoCodeProduct = new Product2(
			Name = 'Some Product',
			Family = 'resi-listing-upgrades-migrated',
			Promo_Code__c = 'PROMO',
			External_ID__c = 'abc-123'
		);
		insert promoCodeProduct;

		SBQQ__QuoteLine__c promoQl = DataFactory.generateSingleQuoteLine();
		promoQl.SBQQ__Quote__c = quotes[0].Id;
		promoQl.SBQQ__Product__c = promoCodeProduct.Id;
		promoQl.Promo_Code__c = 'PROMO';
		insert promoQl;

		Product2 amaxProduct = new Product2(
			Name = 'Amax Product',
			Family = ContractsEmailService.PRODUCT_FAMILY_RCA_AMAX,
			External_ID__c = 'abc-321'
		);
		insert amaxProduct;

		Product2 nonAmaxProduct = new Product2(
			Name = 'Non Amax Product',
			Family = 'Other Depth',
			External_ID__c = 'abc-456'
		);
		insert nonAmaxProduct;

		SBQQ__QuoteLine__c nonAmaxQl = DataFactory.generateSingleQuoteLine();
		nonAmaxQl.SBQQ__Quote__c = quotes[1].Id;
		nonAmaxQl.SBQQ__Product__c = nonAmaxProduct.Id;
		insert nonAmaxQl;

		SBQQ__QuoteLine__c amaxQl = DataFactory.generateSingleQuoteLine();
		amaxQl.SBQQ__Quote__c = quotes[2].Id;
		amaxQl.SBQQ__Product__c = amaxProduct.Id;
		amaxQl.Listing_Agent_Name__c = 'Listing Guy';
		amaxQl.Property_Id__c = 'Prop Id';
		amaxQl.PO_Details__c = 'PO Deets';
		amaxQl.Campaign_Start_Date__c = Date.today().addDays(10);
		insert amaxQl;

		List<echosign_dev1__SIGN_Agreement__c> agreements = new List<echosign_dev1__SIGN_Agreement__c>();

		agreements.add(
			DataFactory.generateSingleAdobeSignAgreement(null, resiQuote.Id)
		);
		agreements.add(
			DataFactory.generateSingleAdobeSignAgreement(opps[1].Id, null)
		);
		agreements.add(
			DataFactory.generateSingleAdobeSignAgreement(null, commercialQuoteAmax.Id)
		);
		agreements.add(
			DataFactory.generateSingleAdobeSignAgreement(null, commercialQuote.Id)
		);
		agreements.add(
			DataFactory.generateSingleAdobeSignAgreement(opps[4].Id, null)
		);
		insert agreements;
	}

	@isTest
	static void shouldSendContractEmailsWhenServiceCalled() {
		External_Emails__c extEmails = External_Emails__c.getInstance();
		extEmails.Zendesk_Contract_Notification__c = 'someemail@test.com';
		insert extEmails;

		Map<Id, echosign_dev1__SIGN_Agreement__c> agreements = new Map<Id, echosign_dev1__SIGN_Agreement__c>(
			[
				SELECT Id, Quote__c, Line_of_Business__c, echosign_dev1__Opportunity__c
				FROM echosign_dev1__SIGN_Agreement__c
			]
		);

		List<Attachment> docs = new List<Attachment>();
		for (echosign_dev1__SIGN_Agreement__c a : agreements.values()) {
			docs.add(
				DataFactory.generateSingleAttachment(
					a.Id,
					'pdf',
					'{"attachmentType":"signed"}'
				)
			);
		}
		insert docs;

		Test.startTest();

		// Email templates must exist
		List<EmailTemplate> emailTemplates = [
			SELECT Id
			FROM EmailTemplate
			WHERE Folder.DeveloperName = :ContractsEmailService.EMAIL_TEMPLATE_FOLDER
		];
		System.assertEquals(5, emailTemplates.size());

		ContractsEmailService.buildAndSendContractsEmails(agreements);
		Integer invocations = Limits.getEmailInvocations();

		Test.stopTest();

		List<Application_Log__c> logs = [
			SELECT Id, Record_ID__c, Severity__c, Error_Description__c
			FROM Application_Log__c
			ORDER BY CreatedDate
		];

		List<EmailMessage> messages = [
			SELECT Id, Subject, HasAttachment
			FROM EmailMessage
		];

		// Should log one error due to missing to email for Commercial Amax
		System.assertEquals(1, logs.size());
		System.assertEquals(1, invocations);
		System.assertEquals(4, messages.size());

		//Email messages should have attachment
		for (EmailMessage e : messages) {
			System.assertEquals(true, e.HasAttachment);
		}
	}
}
