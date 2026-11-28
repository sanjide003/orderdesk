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
    appLanguage: 'en',
    primaryColorHex: 0xFF0F766E,
    customFields: [
      CustomProfileField(
        key: 'origin_island',
        label: 'Origin Island',
        value: 'Chetlat Island, Lakshadweep',
      ),
    ],
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
      origin: 'Made in Chetlat Island, Lakshadweep',
      active: true,
      packs: [
        ProductPack(
          label: '350g',
          price: 549,
          taxNote: '5% GST incl.',
          deliveryCharge: 50,
        ),
        ProductPack(
          label: '1 kg',
          price: 1200,
          taxNote: '5% GST incl.',
          deliveryCharge: 0,
        ),
      ],
      highlights: [
        '🌴 Traditional Lakshadweep recipe',
        '🐟 High-quality Lakshadweep tuna fish',
        '🥥 Natural Lakshadweep Coconut Vinegar',
        '🚫 No artificial colors or flavor enhancers',
      ],
    ),
  ];

  static final List<TemplateModel> templates = [
    const TemplateModel(
      id: '01_welcome',
      order: 1,
      title: 'Welcome & Brand Intro',
      stage: 'welcome',
      bodyMl: '👋 നമസ്കാരം! *{{brand_name}}*-ലേക്ക് ഹൃദയം നിറഞ്ഞ സ്വാഗതം. 😊❤️\n\n'
          'ലക്ഷദ്വീപിന്റെ തനത് രുചികൾ എല്ലാവരിലേക്കും എത്തിക്കുക എന്ന ലക്ഷ്യത്തോടെ ആരംഭിച്ച ഒരു സ്റ്റാർട്ടപ്പ് ബ്രാൻഡാണ് ഞങ്ങൾ.\n\n'
          'ഞങ്ങളുടെ *{{product_name}}*-ന്റെ യഥാർത്ഥ രുചി ആസ്വദിക്കൂ. 🌊🐟\n\n'
          'കൂടുതൽ അറിയാനോ സംശയങ്ങൾ ഉണ്ടെങ്കിലോ ചോദിക്കാവുന്നതാണ്. 😊',
      bodyEn: '👋 Hello! Welcome to *{{brand_name}}*. 😊❤️\n\n'
          'We are a startup dedicated to bringing authentic Lakshadweep flavors straight to your home.\n\n'
          'Experience the real taste of our *{{product_name}}*. 🌊🐟\n\n'
          'Feel free to ask if you have any questions or would like to order! 😊',
      bodyManglish: '👋 Namaskaram! *{{brand_name}}*-lekku hridayam niranja swagatham. 😊❤️\n\n'
          'Lakshadweep-inte thanathu ruchikal ellavarilekkum ethikkuka enna lakshyathode aarambhicha startup brand aanu njangal.\n\n'
          'Njangalude *{{product_name}}*-inte yadhartha ruchi aaswadikku. 🌊🐟\n\n'
          'Kooduthal ariyaano samshayangal undenkilo chodikkavunnathaanu. 😊',
    ),
    const TemplateModel(
      id: '02_product_list',
      order: 2,
      title: 'Product List & Pricing',
      stage: 'pricing',
      bodyMl: '*{{brand_name}} - ലഭ്യമായ പാക്കുകൾ*\n\n{{product_list}}',
      bodyEn: '*{{brand_name}} - Available Packs*\n\n{{product_list}}',
      bodyManglish: '*{{brand_name}} - Labhyamaya Packukal*\n\n{{product_list}}',
    ),
    const TemplateModel(
      id: '03_poster_caption',
      order: 3,
      title: 'Promotional Poster Caption',
      stage: 'poster',
      bodyMl: 'ലക്ഷദ്വീപിന്റെ തനതായ രുചി ഇനി നിങ്ങളുടെ വീട്ടിലും! 🌴🌊\n'
          'ലക്ഷദ്വീപിന്റെ തനത് രുചിക്കൂട്ടിൽ തയ്യാറാക്കിയ *{{product_name}}* ഇന്ന് തന്നെ പരീക്ഷിക്കൂ.\n'
          '📍 {{product_origin}}\n'
          '🚚 ഇന്ത്യയിലുടനീളം ഡെലിവറി ലഭ്യമാണ്.',
      bodyEn: 'Authentic Lakshadweep taste, now at your home! 🌴🌊\n'
          'Try our traditionally crafted *{{product_name}}* today.\n'
          '📍 {{product_origin}}\n'
          '🚚 Pan-India delivery available.',
      bodyManglish: 'Lakshadweep-inte thanathaya ruchi ini ningalude veettilum! 🌴🌊\n'
          'Traditional recipe-il thayyarakkiya *{{product_name}}* innu thanne try cheyyu.\n'
          '📍 {{product_origin}}\n'
          '🚚 India-yil udaneeelam delivery labhyamanu.',
    ),
    const TemplateModel(
      id: '04_address_request',
      order: 4,
      title: 'Order Address Collection',
      stage: 'address',
      bodyMl: '*ഓർഡർ ചെയ്യുന്നതിനായി ദയവായി താഴെ പറയുന്ന വിവരങ്ങൾ അയച്ചുതരുക:*\n\n'
          '1. Full Name\n'
          '2. Contact Number\n'
          '3. Full Delivery Address with Pincode\n\n'
          'സാധാരണയായി 2-5 Working Days-നുള്ളിൽ ഡെലിവറി ലഭിക്കുന്നതാണ്.\n'
          'പേയ്മെന്റ് ചെയ്യുന്നതിനുള്ള QR Code കൺഫോം ചെയ്ത ശേഷം അയച്ചുതരുന്നതാണ്.',
      bodyEn: '*To place your order, please share the following details:*\n\n'
          '1. Full Name\n'
          '2. Contact Number\n'
          '3. Full Delivery Address with Pincode\n\n'
          'Standard delivery takes 2-5 working days.\n'
          'We will share the payment QR code once your details are confirmed.',
      bodyManglish: '*Order cheyyan dayavayi thazhe parayunna details ayachutharuka:*\n\n'
          '1. Full Name\n'
          '2. Contact Number\n'
          '3. Full Delivery Address with Pincode\n\n'
          'Saadharanayayi 2-5 Working Days-nullil delivery labhikkum.\n'
          'Confirm cheytha shesham payment QR Code ayachutharunnathaanu.',
    ),
    const TemplateModel(
      id: '05_payment_details',
      order: 5,
      title: 'Payment Details & Total',
      stage: 'payment',
      bodyMl: '{{order_bill}}\n\n'
          '*Payment Details*\n'
          'മുകളിൽ നൽകിയിരിക്കുന്ന {{payment_bank}} സ്കാൻ ചെയ്ത് പേയ്മെന്റ് ചെയ്യുക.\n\n'
          'പേയ്മെന്റ് പൂർത്തിയാക്കിയ ശേഷം Payment Screenshot ഈ ചാറ്റിൽ അയച്ചുതരുക. നന്ദി.\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
      bodyEn: '{{order_bill}}\n\n'
          '*Payment Details*\n'
          'Please scan the {{payment_bank}} shared above to complete your payment.\n\n'
          'Please share the payment screenshot in this chat after paying. Thank you!\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
      bodyManglish: '{{order_bill}}\n\n'
          '*Payment Details*\n'
          'Mukalil nalkiyirikkunna {{payment_bank}} scan cheythu payment cheyyuka.\n\n'
          'Payment kazhinjal dayavayi Payment Screenshot ee chat-il ayachutharuka. Nandi!\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
    ),
    const TemplateModel(
      id: '06_payment_confirmed',
      order: 6,
      title: 'Payment Received Confirmation',
      stage: 'paid',
      bodyMl: '*Payment Received* ✅\n\n'
          'നന്ദി! താങ്കളുടെ പേയ്മെന്റ് ലഭിച്ചിട്ടുണ്ട്. ഓർഡർ സ്ഥിരീകരിച്ചിരിക്കുന്നു.\n\n'
          '{{courier_name}} വഴി ഡിസ്പാച്ച് ചെയ്ത ഉടൻ Tracking ID ഈ ചാറ്റിൽ പങ്കുവെക്കുന്നതാണ്.\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
      bodyEn: '*Payment Received* ✅\n\n'
          'Thank you! We have received your payment and your order is confirmed.\n\n'
          'We will share your {{courier_name}} Tracking ID here as soon as your parcel is dispatched.\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
      bodyManglish: '*Payment Received* ✅\n\n'
          'Nandi! Thankalude payment labhichittundu. Order confirm aayittundu.\n\n'
          '{{courier_name}} vazhi dispatch cheytha udan Tracking ID ee chat-il share cheyyam.\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
    ),
    const TemplateModel(
      id: '07_dispatched',
      order: 7,
      title: 'Order Dispatched & Tracking',
      stage: 'dispatched',
      bodyMl: '*Order Dispatched Successfully!* ✅\n\n'
          'നമസ്കാരം! താങ്കളുടെ *{{pack_summary}}* വിജയകരമായി *{{courier_name}}* വഴി ഡിസ്പാച്ച് ചെയ്തിരിക്കുന്നു.\n\n'
          '*Tracking ID:* {{tracking_id}}\n\n'
          'ട്രാക്ക് ചെയ്യാനുള്ള ലിങ്ക്:\n{{tracking_url}}\n\n'
          'സാധാരണയായി 2-5 Working Days-നുള്ളിൽ ഡെലിവറി ലഭിക്കും.\n\n'
          'Website: {{website}}\nInstagram: {{instagram_handle}}\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
      bodyEn: '*Order Dispatched Successfully!* ✅\n\n'
          'Hello! Your *{{pack_summary}}* has been dispatched via *{{courier_name}}*.\n\n'
          '*Tracking ID:* {{tracking_id}}\n\n'
          'Track your shipment here:\n{{tracking_url}}\n\n'
          'Estimated delivery: 2-5 working days.\n\n'
          'Website: {{website}}\nInstagram: {{instagram_handle}}\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
      bodyManglish: '*Order Dispatched Successfully!* ✅\n\n'
          'Namaskaram! Thankalude *{{pack_summary}}* *{{courier_name}}* vazhi dispatch cheythirikkunnu.\n\n'
          '*Tracking ID:* {{tracking_id}}\n\n'
          'Status check cheyyan ee link upayogikkam:\n{{tracking_url}}\n\n'
          '2-5 Working Days-nullil delivery labhikkum.\n\n'
          'Website: {{website}}\nInstagram: {{instagram_handle}}\n\n'
          '*{{brand_name}}*\n`{{tagline}}`',
    ),
    const TemplateModel(
      id: '08_review_followup',
      order: 8,
      title: 'Delivery Check-in & Review',
      stage: 'review',
      bodyMl: 'നമസ്കാരം!\n\n'
          'താങ്കളുടെ *{{pack_summary}}* സുരക്ഷിതമായി ലഭിച്ചോ?\n\n'
          'താങ്കളുടെ വിലപ്പെട്ട അഭിപ്രായം Google Review ആയി പങ്കുവെക്കാമോ?\n\n'
          'Google Review:\n{{review_url}}\n\n'
          'Instagram:\n{{instagram_url}}\n\n'
          'നന്ദി!\n*{{brand_name}}*\n`{{tagline}}`',
      bodyEn: 'Hello!\n\n'
          'Did you receive your *{{pack_summary}}* safely?\n\n'
          'We would love to hear your feedback! Please take a moment to leave us a Google Review:\n\n'
          'Google Review:\n{{review_url}}\n\n'
          'Instagram:\n{{instagram_url}}\n\n'
          'Thank you!\n*{{brand_name}}*\n`{{tagline}}`',
      bodyManglish: 'Namaskaram!\n\n'
          'Thankalude *{{pack_summary}}* safe aayi labhicho?\n\n'
          'Thankalude vilappetta abhiprayam Google Review aayi share cheyyamo?\n\n'
          'Google Review:\n{{review_url}}\n\n'
          'Instagram:\n{{instagram_url}}\n\n'
          'Nandi!\n*{{brand_name}}*\n`{{tagline}}`',
    ),
  ];
}
