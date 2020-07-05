public without sharing class ContractsEmailService {
	public static final String EMAIL_TEMPLATE_FOLDER = 'Contracts_Notifications';
	public static final String EMAIL_TEMPLATE_OPP_COMMERCIAL = 'Commercial_Opportunity';
	public static final String EMAIL_TEMPLATE_OPP_DEVELOPER = 'Developer_Opportunity';
	public static final String EMAIL_TEMPLATE_QUOTE_COMMERCIAL = 'Commercial_Quote';
	public static final String EMAIL_TEMPLATE_QUOTE_COMMERCIAL_AMAX = 'Commercial_Quote_Amax';
	public static final String EMAIL_TEMPLATE_QUOTE_RESI = 'Residential_Quote';
	public static final String PRODUCT_FAMILY_RCA_AMAX = 'rca-audience-maximiser';

	public static void buildAndSendContractsEmails(
		Map<Id, echosign_dev1__SIGN_Agreement__c> agreements
	) {
		Map<Id, Id> agreementIdToAttachmentIdMap = getAttachments(
			agreements.keySet()
		);
		Set<Id> quoteIds = new Set<Id>();

		sendEmails(buildEmails(agreements, agreementIdToAttachmentIdMap));
	}

	private static List<ContractsEmailDetails> buildEmails(
		Map<Id, echosign_dev1__SIGN_Agreement__c> agreements,
		Map<Id, Id> agreementIdToAttachmentMap
	) {
		List<ContractsEmailDetails> emailDetails = new List<ContractsEmailDetails>();
		Map<String, Id> emailTemplates = getEmailTemplates();
		Map<Id, List<SBQQ__QuoteLine__c>> agreementToQuoteLineMap = getQuoteLines(
			agreements.values()
		);
		External_Emails__c toEmails = External_Emails__c.getInstance();

		for (echosign_dev1__SIGN_Agreement__c a : agreements.values()) {
			switch on a.Line_of_Business__c {
				when 'Residential' {
					emailDetails.add(
						buildEmail(
							a.Id,
							emailTemplates.get(EMAIL_TEMPLATE_QUOTE_RESI),
							agreementIdToAttachmentMap.get(a.Id),
							new List<String>{toEmails.Zendesk_Contract_Notification__c},
							getPromoCodes(agreementToQuoteLineMap.get(a.Id))
						)
					);
				}
				when 'Commercial' {
					if (a.Quote__c != null) {
						if (
							agreementToQuoteLineMap.get(a.Id)[0].SBQQ__ProductFamily__c ==
							PRODUCT_FAMILY_RCA_AMAX
						) {
							emailDetails.add(
								buildEmail(
									agreementToQuoteLineMap.get(a.Id)[0].Id,
									emailTemplates.get(EMAIL_TEMPLATE_QUOTE_COMMERCIAL_AMAX),
									agreementIdToAttachmentMap.get(a.Id),
									new List<String>{
										toEmails.Zendesk_Contract_Notification__c,
										toEmails.Commercial_Sales_Coordinator__c
									},
									getPromoCodes(agreementToQuoteLineMap.get(a.Id))
								)
							);
						} else {
							emailDetails.add(
								buildEmail(
									a.Id,
									emailTemplates.get(EMAIL_TEMPLATE_QUOTE_COMMERCIAL),
									agreementIdToAttachmentMap.get(a.Id),
									new List<String>{toEmails.Zendesk_Contract_Notification__c},
									getPromoCodes(agreementToQuoteLineMap.get(a.Id))
								)
							);
						}
					} else if (a.echosign_dev1__Opportunity__c != null) {
						emailDetails.add(
							buildEmail(
								a.Id,
								emailTemplates.get(EMAIL_TEMPLATE_OPP_COMMERCIAL),
								agreementIdToAttachmentMap.get(a.Id),
								new List<String>{toEmails.Zendesk_Contract_Notification__c},
								''
							)
						);
					}
				}
				when 'Developer' {
					emailDetails.add(
						buildEmail(
							a.Id,
							emailTemplates.get(EMAIL_TEMPLATE_OPP_DEVELOPER),
							agreementIdToAttachmentMap.get(a.Id),
							new List<String>{toEmails.Zendesk_Contract_Notification__c},
							''
						)
					);
				}
			}
		}

		return emailDetails;
	}

	private static ContractsEmailDetails buildEmail(
		Id relatedToId,
		Id templateId,
		Id attachmentId,
		List<String> toEmails,
		String promoCodes
	) {
		ContractsEmailDetails ed = new ContractsEmailDetails();
		ed.relatedToId = relatedToId;
		ed.templateId = templateId;
		ed.attachmentId = attachmentId;
		ed.toEmails = toEmails;
		ed.promoCodes = promoCodes;
		return ed;
	}

	private static Map<Id, Id> getAttachments(Set<Id> agreementIds) {
		Map<Id, Id> agreementIdToAttachmentIdMap = new Map<Id, Id>();
		// Take a list of Agreements, get required related objects and construct emails
		List<Attachment> contracts = [
			SELECT Id, Description, ParentId
			FROM Attachment
			WHERE ParentId IN :agreementIds
		];

		for (Attachment c : contracts) {
			if (c.Description != null) {
				Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(
					c.Description
				);

				String attachmentType = (String) json.get('attachmentType');
				if (
					attachmentType.equalsIgnoreCase(AdobeSignAgreements.STATUS_SIGNED)
				) {
					agreementIdToAttachmentIdMap.put(c.ParentId, c.Id);
				}
			}
		}
		return agreementIdToAttachmentIdMap;
	}

	private static Map<Id, List<SBQQ__QuoteLine__c>> getQuoteLines(
		List<echosign_dev1__SIGN_Agreement__c> agreements
	) {
		Map<Id, Id> quoteIdToAgreementIdMap = new Map<Id, Id>();
		Map<Id, List<SBQQ__QuoteLine__c>> agreementToQuoteLineMap = new Map<Id, List<SBQQ__QuoteLine__c>>();

		for (echosign_dev1__SIGN_Agreement__c ag : agreements) {
			if (ag.Quote__c != null) {
				quoteIdToAgreementIdMap.put(ag.Quote__c, ag.Id);
				agreementToQuoteLineMap.put(ag.Id, new List<SBQQ__QuoteLine__c>());
			}
		}

		List<SBQQ__QuoteLine__c> quoteLines = [
			SELECT Id, SBQQ__Quote__c, SBQQ__ProductFamily__c, Promo_Code__c
			FROM SBQQ__QuoteLine__c
			WHERE
				SBQQ__Quote__c IN :quoteIdToAgreementIdMap.keySet()
				AND ExternalId__c != null
			ORDER BY SBQQ__Quote__c
		];

		// Filter quote lines where the prioduct family is RCA Amax as we need the related to object to be quote line
		for (SBQQ__QuoteLine__c ql : quoteLines) {
			Id agreementId = quoteIdToAgreementIdMap.get(ql.SBQQ__Quote__c);
			agreementToQuoteLineMap.get(agreementId).add(ql);
		}
		return agreementToQuoteLineMap;
	}

	private static Map<String, Id> getEmailTemplates() {
		List<EmailTemplate> emailTemplates = [
			SELECT Id, DeveloperName
			FROM EmailTemplate
			WHERE Folder.DeveloperName = :EMAIL_TEMPLATE_FOLDER
		];

		Map<String, Id> templateNameToIdMap = new Map<String, Id>();
		for (EmailTemplate e : emailTemplates) {
			templateNameToIdMap.put(e.DeveloperName, e.Id);
		}

		return templateNameToIdMap;
	}

	private static String getPromoCodes(List<SBQQ__QuoteLine__c> quoteLines) {
		Set<String> promoCodes = new Set<String>();
		String promoCodesString = '';

		for (SBQQ__QuoteLine__c ql : quoteLines) {
			if (
				!String.isBlank(ql.Promo_Code__c) &&
				!promoCodes.contains(ql.Promo_Code__c)
			) {
				promoCodesString = promoCodesString + ql.Promo_Code__c + ';';
				promoCodes.add(ql.Promo_Code__c);
			}
		}
		return promoCodesString;
	}

	private static void sendEmails(
		List<ContractsEmailDetails> contractsEmailDetails
	) {
		List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
		List<Id> agreementIds = new List<Id>();

		for (ContractsEmailDetails ed : contractsEmailDetails) {
			Messaging.SingleEmailMessage msg = Messaging.renderStoredEmailTemplate(
				ed.templateId,
				null,
				ed.relatedToId
			);
			msg.setToAddresses(ed.toEmails);
			msg.setEntityAttachments(new List<String>{ed.attachmentId});
			msg.setHtmlBody(
				msg.getHtmlBody().replace('{{promo_codes}}', ed.promoCodes)
			);
			messages.add(msg);
			agreementIds.add(ed.relatedToId);
		}

		if (!messages.isEmpty()) {
			List<Messaging.SendEmailResult> results = Messaging.sendEmail(
				messages,
				false
			);
			logEmailResults(results, agreementIds);
		}
	}

	private static void logEmailResults(
		List<Messaging.SendEmailResult> results,
		List<Id> relatedToIds
	) {
		List<Application_Log__c> logs = new List<Application_Log__c>();
		for (Integer i = 0; i < results.size(); i++) {
			if (
				results[i].isSuccess() == false && !results[i].getErrors().isEmpty()
			) {
				String error = '';
				for (Messaging.SendEmailError e : results[i].getErrors()) {
					if (e.getMessage() != null) {
						error = error + e.getMessage() + '\n';
					}
				}
				logs.add(
					new Application_Log__c(
						Process_Name__c = 'ContractsEmailService',
						Function_Name__c = 'SendEmails',
						Record_Id__c = relatedToIds[i],
						Error_Description__c = error,
						Severity__c = rea_SystemLog.Severity.ERROR.name()
					)
				);
			}
		}
		insert logs;
	}

	public class ContractsEmailDetails {
		public Id relatedToId { get; set; }
		public Id templateId { get; set; }
		public Id attachmentId { get; set; }
		public List<String> toEmails { get; set; }
		public String promoCodes { get; set; }
	}
}
