import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';

class LakfaSeedData {
  static const BusinessProfile profile = BusinessProfile(
    brandName: 'Lakfa Foods',
    tagline: 'The Tasty Secrets of Lakshadweep',
    phone: '+91 79073 45458',
    website: 'www.lakfafoods.com',
    instagramHandle: '@lakfaofficial',
    instagramUrl: 'https://instagram.com/lakfaofficial',
    reviewUrl: 'https://share.google/DgU5VLlj9bS9n8DCb',
    courierName: 'DTDC Courier',
    trackingUrl: 'https://www.dtdc.com/track-your-shipment/',
    paymentBankLabel: 'HDFC Bank QR Code',
    primaryColorHex: 0xFF0F766E,
  );

  static const DeliveryRules deliveryRules = DeliveryRules(
    mode: DeliveryMode.perPack,
    flatCharge: 50,
    freeThresholdAmount: 1000,
    belowThresholdCharge: 50,
  );

  static final List<ProductModel> products = [
    const ProductModel(
      id: 'lakfa_tuna_pickle',
      name: 'Lakfa Tuna Pickle',
      origin: 'ചെത്‌ലത്ത് ദ്വീപിൽ നിർമ്മിച്ചത്',
      active: true,
      packs: [
        ProductPack(
          label: '350g',
          price: 549,
          taxNote: '5% GST ഉൾപ്പെടെ',
          deliveryCharge: 50,
        ),
        ProductPack(
          label: '1 kg',
          price: 1200,
          taxNote: '5% GST ഉൾപ്പെടെ',
          deliveryCharge: 0,
        ),
      ],
      highlights: [
        '🌴 ലക്ഷദ്വീപിന്റെ പാരമ്പര്യ രുചിക്കൂട്ട്',
        '🐟 ഉയർന്ന നിലവാരമുള്ള ട്യൂണ മത്സ്യം',
        '🥥 ലക്ഷദ്വീപ് തേങ്ങാ വിനാഗിരി (Coconut Vinegar)',
        '🚫 കൃത്രിമ നിറങ്ങളോ രുചി വർധകങ്ങളോ ഇല്ല',
      ],
      posterCaption:
          'ലക്ഷദ്വീപിന്റെ തനതായ രുചി ഇനി നിങ്ങളുടെ വീട്ടിലും! 🌴🌊
'
          'ലക്ഷദ്വീപിന്റെ തനത് രുചിക്കൂട്ടിൽ തയ്യാറാക്കിയ *Lakfa Tuna Pickle* ഇന്ന് തന്നെ പരീക്ഷിക്കൂ.
'
          '📍 ചെത്‌ലത്ത് ദ്വീപിൽ നിർമ്മിച്ചത്
'
          '🚚 ഇന്ത്യയിലുടനീളം ഡെലിവറി ലഭ്യമാണ്.',
    ),
  ];

  static final List<TemplateModel> templates = [
    const TemplateModel(
      id: '01_welcome',
      order: 1,
      title: '1. Welcome & Intro',
      stage: 'welcome',
      body: '👋 നമസ്കാരം! *{{brand_name}}*-ലേക്ക് ഹൃദയം നിറഞ്ഞ സ്വാഗതം. 😊❤️

'
          'ലക്ഷദ്വീപിന്റെ തനത് രുചികൾ എല്ലാവരിലേക്കും എത്തിക്കുക എന്ന ലക്ഷ്യത്തോടെ ആരംഭിച്ച ഒരു സ്റ്റാർട്ടപ്പ് ബ്രാൻഡാണ് ഞങ്ങൾ.

'
          'ലക്ഷദ്വീപിലെ തെളിഞ്ഞ കടലിൽ നിന്ന് നേരിട്ട് പിടിക്കുന്ന മികച്ച ട്യൂണ മത്സ്യം മാത്രം ഉപയോഗിച്ച് തയ്യാറാക്കുന്ന ഞങ്ങളുടെ *Lakfa Tuna Pickle*-ന്റെ യഥാർത്ഥ രുചി ആസ്വദിക്കൂ. 🌊🐟

'
          'ഞങ്ങളുടെ ഉൽപ്പന്നത്തെക്കുറിച്ച് കൂടുതൽ അറിയാനോ എന്തെങ്കിലും സംശയങ്ങൾ ഉണ്ടെങ്കിലോ ചോദിക്കാവുന്നതാണ്. 😊',
    ),
    const TemplateModel(
      id: '02_product_list',
      order: 2,
      title: '2. Product List & Pricing',
      stage: 'pricing',
      body: '*{{brand_name}} - ലഭ്യമായ പാക്കുകൾ*

{{product_list}}',
    ),
    const TemplateModel(
      id: '03_poster_standard',
      order: 3,
      title: '3. Poster Caption (Standard)',
      stage: 'poster',
      body: 'ലക്ഷദ്വീപിന്റെ തനതായ രുചി ഇനി നിങ്ങളുടെ വീട്ടിലും! 🌴🌊
'
          'ലക്ഷദ്വീപിന്റെ തനത് രുചിക്കൂട്ടിൽ തയ്യാറാക്കിയ *Lakfa Tuna Pickle* ഇന്ന് തന്നെ പരീക്ഷിക്കൂ.
'
          '📍 ചെത്‌ലത്ത് ദ്വീപിൽ നിർമ്മിച്ചത്
'
          '🚚 ഇന്ത്യയിലുടനീളം ഡെലിവറി ലഭ്യമാണ്.',
    ),
    const TemplateModel(
      id: '04_poster_vinegar',
      order: 4,
      title: '4. Poster Caption (സുർക്ക)',
      stage: 'poster',
      body: 'ലക്ഷദ്വീപിന്റെ തനതായ രുചി ഇനി നിങ്ങളുടെ വീട്ടിലും! 🌴🌊
'
          'ലക്ഷദ്വീപ് തേങ്ങാ സുർക്കയുടെ (Coconut Vinegar) പെരുമയിൽ തയ്യാറാക്കിയ *Lakfa Tuna Pickle* പരീക്ഷിക്കൂ.
'
          '📍 ചെത്‌ലത്ത് ദ്വീപിൽ നിർമ്മിച്ചത്
'
          '🚚 ഇന്ത്യയിലുടനീളം ഡെലിവറി ലഭ്യമാണ്.',
    ),
    const TemplateModel(
      id: '05_address_request',
      order: 5,
      title: '5. Order Address Collection',
      stage: 'address',
      body: '*ഓർഡർ ചെയ്യുന്നതിനായി ദയവായി താഴെ പറയുന്ന വിവരങ്ങൾ അയച്ചുതരുക:*

'
          '1. Full Name
'
          '2. Contact Number
'
          '3. Full Delivery Address with Pincode

'
          'സാധാരണയായി 2-5 Working Days-നുള്ളിൽ ഡെലിവറി ലഭിക്കുന്നതാണ്.
'
          'പേയ്മെന്റ് ചെയ്യുന്നതിനുള്ള QR Code കൺഫോം ചെയ്ത ശേഷം അയച്ചുതരുന്നതാണ്.',
    ),
    const TemplateModel(
      id: '06_payment_details',
      order: 6,
      title: '6. Payment Details & Total',
      stage: 'payment',
      body: '*Payment Details*

'
          'മുകളിൽ നൽകിയിരിക്കുന്ന {{payment_bank}} സ്കാൻ ചെയ്ത് പേയ്മെന്റ് ചെയ്യുക.

'
          '*ആകെ അടയ്ക്കേണ്ട തുക:*
'
          '• Product Price: {{subtotal}}
'
          '• Delivery Charge: {{delivery_charge}}
'
          '• *Total Amount: {{total_amount}}*

'
          'പേയ്മെന്റ് വിജയകരമായി പൂർത്തിയാക്കിയ ശേഷം ദയവായി Payment Screenshot ഈ ചാറ്റിൽ അയച്ചുതരുക.

'
          'നന്ദി.

'
          '*{{brand_name}}*
'
          '`{{tagline}}`',
    ),
    const TemplateModel(
      id: '07_payment_confirmed',
      order: 7,
      title: '7. Payment Confirmed',
      stage: 'paid',
      body: '*Payment Received* ✅

'
          'നന്ദി! താങ്കളുടെ പേയ്മെന്റ് വിജയകരമായി ലഭിച്ചിട്ടുണ്ട്. താങ്കളുടെ ഓർഡർ സ്ഥിരീകരിച്ചിരിക്കുന്നു.

'
          'ഓർഡർ പാക്ക് ചെയ്ത് {{courier_name}} വഴി ഡിസ്പാച്ച് ചെയ്ത ഉടൻ Tracking ID ഈ ചാറ്റിൽ പങ്കുവെക്കുന്നതാണ്.

'
          '{{brand_name}} തിരഞ്ഞെടുത്തതിന് ഹൃദയം നിറഞ്ഞ നന്ദി.

'
          '*{{brand_name}}*
'
          '`{{tagline}}`',
    ),
    const TemplateModel(
      id: '08_dispatched',
      order: 8,
      title: '8. Order Dispatched (DTDC)',
      stage: 'dispatched',
      body: '*Order Dispatched Successfully!* ✅

'
          'നമസ്കാരം! താങ്കളുടെ *{{pack_summary}}* വിജയകരമായി *{{courier_name}}* വഴി ഡിസ്പാച്ച് ചെയ്തിരിക്കുന്നു.

'
          '*Tracking ID:* {{tracking_id}}

'
          'താങ്കളുടെ പാർസലിന്റെ നിലവിലെ സ്റ്റാറ്റസ് താഴെ നൽകിയിരിക്കുന്ന ലിങ്കിൽ Tracking ID നൽകി പരിശോധിക്കാവുന്നതാണ്:
'
          '{{tracking_url}}

'
          'സാധാരണയായി 2-5 Working Days-നുള്ളിൽ ഡെലിവറി ലഭിക്കുന്നതാണ്. എന്തെങ്കിലും സഹായം ആവശ്യമുണ്ടെങ്കിൽ ഈ WhatsApp ചാറ്റിൽ തന്നെ സന്ദേശം അയക്കാവുന്നതാണ്.

'
          '{{brand_name}} തിരഞ്ഞെടുത്തതിന് ഹൃദയം നിറഞ്ഞ നന്ദി.

'
          'Website: {{website}}
'
          'Instagram: {{instagram_handle}}

'
          '*{{brand_name}}*
'
          '`{{tagline}}`',
    ),
    const TemplateModel(
      id: '09_review_followup',
      order: 9,
      title: '9. Delivery Check-in & Review',
      stage: 'review',
      body: 'നമസ്കാരം!

'
          'താങ്കളുടെ *{{pack_summary}}* സുരക്ഷിതമായി ലഭിച്ചോ?

'
          'ഞങ്ങളുടെ ഉൽപ്പന്നത്തെക്കുറിച്ചുള്ള താങ്കളുടെ വിലപ്പെട്ട അഭിപ്രായം Google Review ആയി പങ്കുവെക്കാൻ ഒരു നിമിഷം സമയം കണ്ടെത്തുമോ? അത് ഞങ്ങൾക്ക് ഏറെ പ്രോത്സാഹനമാകും.

'
          'Google Review:
'
          '{{review_url}}

'
          'Instagram:
'
          '{{instagram_url}}

'
          'താങ്കളുടെ അഭിപ്രായം ഞങ്ങളുടെ ഉൽപ്പന്നവും സേവനവും കൂടുതൽ മെച്ചപ്പെടുത്താനും, പുതിയ ഉപഭോക്താക്കൾക്ക് വിശ്വാസം നൽകാനും ഏറെ സഹായകരമാണ്.

'
          'എന്തെങ്കിലും സഹായം ആവശ്യമുണ്ടെങ്കിൽ ഈ WhatsApp ചാറ്റിൽ തന്നെ സന്ദേശം അയക്കാവുന്നതാണ്. നന്ദി!

'
          '*{{brand_name}}*
'
          '`{{tagline}}`',
    ),
  ];
}
