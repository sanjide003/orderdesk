import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderdesk/services/whatsapp_formatter.dart';
import 'package:orderdesk/widgets/whatsapp_rich_text.dart';

void main() {
  group('WhatsAppFormatter inline & block formatting', () {
    test('wraps and unwraps bold, italic, strike, monospace, and inline code', () {
      final cases = <WhatsAppInlineFormat, String>{
        WhatsAppInlineFormat.bold: '*',
        WhatsAppInlineFormat.italic: '_',
        WhatsAppInlineFormat.strikethrough: '~',
        WhatsAppInlineFormat.monospace: '```',
        WhatsAppInlineFormat.inlineCode: '`',
      };

      for (final entry in cases.entries) {
        final ctrl = TextEditingController(text: 'Hello World');
        ctrl.selection = const TextSelection(baseOffset: 6, extentOffset: 11);

        WhatsAppFormatter.toggleInline(ctrl, entry.key);
        expect(ctrl.text, 'Hello ${entry.value}World${entry.value}');

        // Toggle off when inner text remains selected
        WhatsAppFormatter.toggleInline(ctrl, entry.key);
        expect(ctrl.text, 'Hello World');
        ctrl.dispose();
      }
    });

    test('inserts empty markers at cursor and centers cursor inside', () {
      final ctrl = TextEditingController(text: 'Hi ');
      ctrl.selection = const TextSelection.collapsed(offset: 3);

      WhatsAppFormatter.toggleInline(ctrl, WhatsAppInlineFormat.bold);
      expect(ctrl.text, 'Hi **');
      expect(ctrl.selection, const TextSelection.collapsed(offset: 4));

      // Tapping again removes empty markers cleanly
      WhatsAppFormatter.toggleInline(ctrl, WhatsAppInlineFormat.bold);
      expect(ctrl.text, 'Hi ');
      expect(ctrl.selection, const TextSelection.collapsed(offset: 3));
      ctrl.dispose();
    });

    test('toggles bulleted, numbered, and block quote prefixes across lines', () {
      final ctrl = TextEditingController(text: 'Apple\nOrange\nMango');
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 18);

      WhatsAppFormatter.toggleLinePrefix(
          ctrl, WhatsAppLineFormat.bulletedList);
      expect(ctrl.text, '- Apple\n- Orange\n- Mango');

      WhatsAppFormatter.toggleLinePrefix(
          ctrl, WhatsAppLineFormat.numberedList);
      expect(ctrl.text, '1. Apple\n2. Orange\n3. Mango');

      WhatsAppFormatter.toggleLinePrefix(ctrl, WhatsAppLineFormat.blockQuote);
      expect(ctrl.text, '> Apple\n> Orange\n> Mango');

      WhatsAppFormatter.toggleLinePrefix(ctrl, WhatsAppLineFormat.blockQuote);
      expect(ctrl.text, 'Apple\nOrange\nMango');
      ctrl.dispose();
    });

    test('auto-continues bullets, numbered items, and quotes on Enter and exits on empty line', () {
      // Numbered continuation
      final ctrl = TextEditingController(text: '1. First Item\n');
      ctrl.selection = const TextSelection.collapsed(offset: 14);
      var text = WhatsAppFormatter.handleEnterAutoContinue(ctrl, '1. First Item');
      expect(text, '1. First Item\n2. ');
      expect(ctrl.selection, const TextSelection.collapsed(offset: 17));

      // Pressing Enter on empty "2. " exits list cleanly
      ctrl.value = const TextEditingValue(
        text: '1. First Item\n2. \n',
        selection: TextSelection.collapsed(offset: 18),
      );
      text = WhatsAppFormatter.handleEnterAutoContinue(ctrl, '1. First Item\n2. ');
      expect(text, '1. First Item\n');
      expect(ctrl.selection, const TextSelection.collapsed(offset: 14));

      // Bulleted continuation
      ctrl.value = const TextEditingValue(
        text: '- Apple\n',
        selection: TextSelection.collapsed(offset: 8),
      );
      text = WhatsAppFormatter.handleEnterAutoContinue(ctrl, '- Apple');
      expect(text, '- Apple\n- ');

      // Block quote continuation
      ctrl.value = const TextEditingValue(
        text: '> Quote\n',
        selection: TextSelection.collapsed(offset: 8),
      );
      text = WhatsAppFormatter.handleEnterAutoContinue(ctrl, '> Quote');
      expect(text, '> Quote\n> ');

      ctrl.dispose();
    });

    test('inserts variable at cursor position without overwriting surrounding text', () {
      final ctrl = TextEditingController(text: 'Hello , thank you!');
      ctrl.selection = const TextSelection.collapsed(offset: 6);
      WhatsAppFormatter.insertAtCursor(ctrl, '{{brand_name}}');
      expect(ctrl.text, 'Hello {{brand_name}}, thank you!');
      expect(ctrl.selection, const TextSelection.collapsed(offset: 20));
      ctrl.dispose();
    });
  });

  testWidgets('WhatsAppRichText renders all 8 styles without breaking URLs',
      (tester) async {
    const sample = '''
*Bold Text* _Italic Text_ ~Strike Text~ `Inline Code`
```Monospace Text```
- Apple
1. First Item
> Block Quote
https://example.com/my_order_link
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WhatsAppRichText(text: sample),
        ),
      ),
    );

    expect(find.textContaining('Bold Text', findRichText: true), findsOneWidget);
    expect(find.textContaining('Italic Text', findRichText: true), findsOneWidget);
    expect(find.textContaining('Strike Text', findRichText: true), findsOneWidget);
    expect(find.textContaining('Inline Code', findRichText: true), findsOneWidget);
    expect(find.textContaining('Monospace Text', findRichText: true), findsOneWidget);
    expect(find.text('•'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.textContaining('Block Quote', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('https://example.com/my_order_link', findRichText: true),
      findsOneWidget,
    );
  });
}
