/// The English title, description and "not for" list of each item, which the
/// site shows instead of the manifest's `title`, `description` and
/// `meta.notFor`, in French. They live here and not in the manifest: its
/// digest goes into the published index, and one more field there would
/// change the already published version 0.1.0 (rule 2). `notFor` follows
/// `meta.notFor` entry for entry, in the same order (`[]` when the manifest
/// has none), and keeps the item names in parentheses. A French version of
/// the site reuses the manifest's fields. `site_test.dart` requires one entry
/// per registry item, and not one more, and as many `notFor` entries as the
/// manifest.
const Map<String, ({String title, String description, List<String> notFor})>
itemEnglish = {
  'core': (
    title: 'Core',
    description:
        'Gives every component its tokens, light and dark themes, density, '
        'platform typography, reduced motion and an accessible pressable '
        'surface. No Material, no Cupertino.',
    notFor: [],
  ),
  'icons': (
    title: 'Icons',
    description:
        'Gives 58 mobile icons as Flutter paths, from Gravity UI, Lucide, '
        'Tabler or Phosphor as the preset says: arrows, chevrons, search, '
        'cart, heart, play. Directional ones flip right to left.',
    notFor: [
      'a tappable close cross: use a close button (close-button)',
      'a menu that slides from the edge, opened by the three-line icon: use a '
          'drawer (drawer)',
    ],
  ),
  'button': (
    title: 'Button',
    description:
        'Triggers the main action of a screen or form. Primary, secondary or '
        'ghost, with loading, leading icon, visible keyboard focus and the '
        'platform tap target.',
    notFor: ['an on/off toggle: use a switch (switch)'],
  ),
  'checkbox': (
    title: 'Checkbox',
    description:
        'Lets people check one option, or several in a list. A box with a '
        'check drawn stroke by stroke, mixed and invalid states, '
        'visible keyboard focus.',
    notFor: [
      'a setting that takes effect immediately: use a switch (switch)',
      'a single choice among several: use radio buttons (radio)',
      'a form that requires at least one checked box: use a checkbox group '
          '(checkbox-group)',
    ],
  ),
  'dialog': (
    title: 'Modal dialog',
    description:
        'Asks for a decision or a confirmation before going on, over a dimmed '
        'page. Title, scrolling text, actions, close button, swipe down to '
        'dismiss, trapped focus, Escape and focus returned on close.',
    notFor: [
      'anchored content that does not block the page: use a popover (popover)',
      'a list of actions: use a menu (menu)',
      'a hint on hover: use a tooltip (tooltip)',
    ],
  ),
  'list-row': (
    title: 'List row',
    description:
        'Shows list or settings entries grouped on a surface between dividers, '
        'pressable by touch or keyboard, with prefix, title, subtitle, value '
        'and chevron.',
    notFor: ['a standalone main action: use a button (button)'],
  ),
  'card': (
    title: 'Card',
    description:
        'Groups a header, a title, a description and actions on a shadowed '
        'surface: a product, an offer, an account summary.',
    notFor: [
      'a plain background with no title or description: use a surface '
          '(surface)',
      'a window over the page: use a dialog (dialog)',
      'a bubble opened against a button: use a popover (popover)',
    ],
  ),
  'accordion': (
    title: 'Accordion',
    description:
        'Groups sections that open one at a time or together from their '
        'header, with a spring height, a content fade and a turning chevron.',
    notFor: [
      'navigation between sibling views: use tabs (tabs)',
      'a list of settings that open a screen: use a list row (list-row)',
    ],
  ),
  'alert': (
    title: 'Inline alert',
    description:
        'Reports information, success, a warning or an error in the page, '
        'with the status icon and color, a title, a description and an action.',
    notFor: [
      'a passing message after an action: use a toast (toast)',
      'an input error on a field: use the field\'s error message (field)',
      'a confirmation before an irreversible action: use a dialog (dialog)',
    ],
  ),
  'chip': (
    title: 'Chip',
    description:
        'Shows a status, a category or a filter as a short label in a colored '
        'capsule, pressable when needed.',
    notFor: [
      'a main action: use a button (button)',
      'a message about the page\'s state: use an inline alert (alert)',
    ],
  ),
  'avatar': (
    title: 'Avatar',
    description:
        'Shows a person by their round photo, which fades in once loaded, or '
        'else by their initials or a silhouette.',
    notFor: ['a status or category in text: use a chip (chip)'],
  ),
  'menu': (
    title: 'Action menu',
    description:
        'Lets people pick an action from a list opened by a control, by touch '
        'or keyboard. Checked options, a submenu that '
        'unfolds in place, or a bottom sheet.',
    notFor: [
      'free content or a form, anchored: use a popover (popover)',
      'a confirmation that blocks the screen: use a dialog (dialog)',
      'picking a value among exclusive options: use radio buttons (radio)',
      'a navigation panel that slides from the left edge, opened by the '
          'three-bar icon: use a drawer (drawer)',
    ],
  ),
  'popover': (
    title: 'Anchored popover',
    description:
        'Opens free content next to the control that opens it, closed by a '
        'tap outside or Escape. A panel with a title, text, a '
        'close button and an arrow, or a bottom sheet.',
    notFor: [
      'a list of actions to pick from: use a menu (menu)',
      'a short label on hover or long press: use a tooltip (tooltip)',
      'a decision that blocks the screen: use a dialog (dialog)',
    ],
  ),
  'progress': (
    title: 'Progress indicator',
    description:
        'Shows how far a task has gone, or that it is running. A bar and a '
        'ring in three sizes and five colors, with label and percentage; the '
        'running bar stands still when motion is reduced.',
    notFor: [
      'a button that starts the action and waits: use the button\'s loading '
          'state (button)',
      'a value the user sets: use a slider (slider)',
    ],
  ),
  'radio': (
    title: 'Radio button',
    description:
        'Lets people choose exactly one option among several. A group and '
        'options, labels included, on the Flutter RadioGroup: one '
        'Tab stop, arrows change the option.',
    notFor: [
      'several choices allowed: use checkboxes (checkbox)',
      'an on/off setting that takes effect immediately: use a switch (switch)',
    ],
  ),
  'sheet': (
    title: 'Bottom sheet',
    description:
        'Opens a panel from the bottom of the screen for a short task, dragged '
        'or closed. Spring snap points, icon, title, text, actions, close '
        'button, scrim, trapped focus and Escape.',
    notFor: [
      'an on/off choice in a settings list: use a list row (list-row)',
      'the page\'s main action: use a button (button)',
    ],
  ),
  'slider': (
    title: 'Slider',
    description:
        'Lets people pick a value or a range by dragging, tapping the track or '
        'with the keyboard. One or two thumbs, divisions, label and value, '
        'horizontal or vertical.',
    notFor: [
      'turning a setting on or off: use a switch (switch)',
      'entering an exact value: use a text field (text-field)',
    ],
  ),
  'switch': (
    title: 'Switch',
    description:
        'Turns a setting on or off with a tap or a drag. The track turns to '
        'the accent, a spring thumb, still when motion is reduced.',
    notFor: [
      'a choice among several exclusive options: use radio buttons (radio)',
      'accepting terms before sending: use a checkbox (checkbox)',
    ],
  ),
  'tabs': (
    title: 'Tabs',
    description:
        'Moves between views at the same level of a screen. Segmented or '
        'underlined tabs with a spring indicator, disabled tabs, '
        'separators and arrow key navigation.',
    notFor: [
      'picking an exclusive option in a form: use radio buttons (radio)',
      'triggering a one-off action: use a button (button)',
      'picking a period or a filter among a few short options: use a '
          'segmented control (segmented)',
    ],
  ),
  'link-button': (
    title: 'Link',
    description:
        'Opens a related page from a sentence, such as terms or help: a '
        'pressable label with no background or padding, in three sizes.',
    notFor: ['a screen\'s main action: use a button (button)'],
  ),
  'stepper': (
    title: 'Stepper',
    description:
        'Sets a small count one step at a time, with round minus and plus '
        'buttons around the number at the end of a row: guests, quantity, '
        'seats. Each button turns off at its limit.',
    notFor: [
      'a number typed on the keyboard, a price, a weight: use the number '
          'field (number-field)',
      'a value on a continuous range: use the slider (slider)',
      'a quantity in a cart line: use the cart line (cart-line)',
    ],
  ),
  'number-field': (
    title: 'Number field',
    description:
        'Sets a quantity or a number of guests between two limits, typed or '
        'nudged with minus and plus buttons that repeat while held, read out '
        'as an adjustable value.',
    notFor: [
      'an approximate value on a continuous range: use a slider (slider)',
      'free text, email or password: use a text field (text-field)',
      'a choice among a list of named values: use a select (select)',
    ],
  ),
  'segmented': (
    title: 'Segmented control',
    description:
        'Picks one of two to five short options shown side by side, such as '
        'day, week or month, with a sliding selection and radio group '
        'semantics.',
    notFor: [
      'sections or categories that change the whole view: use tabs (tabs)',
      'long options, or more than five: use radio buttons (radio)',
      'a long list of choices in a form: use a select (select)',
      'a continuous value between a minimum and a maximum: use a slider '
          '(slider)',
    ],
  ),
  'calendar': (
    title: 'Calendar',
    description:
        'Picks one day from a month grid, for an appointment or a delivery: '
        'previous and next month, a quick year picker, unavailable and '
        'out-of-range days, each day read out in full.',
    notFor: [
      'a period with a start and an end: use a range calendar (range-calendar)',
      'a choice between day, week or month above a chart: use a segmented '
          'control (segmented)',
      'a value from a short list, such as a single month: use a select '
          '(select)',
      'a form field that opens the grid on tap: use a date picker '
          '(date-picker)',
      'a known date typed on the keyboard, such as a birth date: use a date '
          'field (date-field)',
    ],
  ),
  'range-calendar': (
    title: 'Range calendar',
    description:
        'Picks a period from a month grid, a first then a last day, for a '
        'stay or a rental: the days between are highlighted, and the range '
        'never crosses an unavailable day.',
    notFor: [
      'a single day: use a calendar (calendar)',
      'a preset duration such as 7 or 30 days: use a segmented control '
          '(segmented)',
      'a form field that opens the grid on tap: use a date range picker '
          '(date-range-picker)',
    ],
  ),
  'date-picker': (
    title: 'Date picker',
    description:
        'Picks a date from a form field that opens the calendar, as a bottom '
        'sheet on phones and a popover on tablets, with the chosen date '
        'written out in full and a button to clear it.',
    notFor: [
      'a month grid always visible on the screen: use a calendar (calendar)',
      'a period with a start and an end: use a date range picker '
          '(date-range-picker)',
      'a known date typed on the keyboard: use a date field (date-field)',
    ],
  ),
  'date-range-picker': (
    title: 'Date range picker',
    description:
        'Picks a period from a form field that opens the range calendar, as a '
        'bottom sheet on phones: the field shows the first and last day, and '
        'a start alone is never sent.',
    notFor: [
      'a period always visible on the screen: use a range calendar '
          '(range-calendar)',
      'a single day: use a date picker (date-picker)',
    ],
  ),
  'date-field': (
    title: 'Date field',
    description:
        'Types a known date on the keyboard, day, month and year in the order '
        'of the language, each segment read out by name and value and '
        'adjustable by swipe.',
    notFor: [
      'a date picked by browsing months: use a date picker (date-picker)',
      'a time of day: use a time field (time-field)',
    ],
  ),
  'time-field': (
    title: 'Time field',
    description:
        'Types a time on the keyboard, hours and minutes, with AM or PM when '
        'the language counts twelve hours; the value counts as soon as it is '
        'complete.',
    notFor: [
      'a duration or a countdown: use a number field (number-field)',
      'a calendar date: use a date field (date-field)',
    ],
  ),
  'checkbox-group': (
    title: 'Checkbox group',
    description:
        'Ticks several options under one label, description and error, such '
        'as interests or alert channels, read by screen readers as one named '
        'group.',
    notFor: [
      'a single option among several: use radio buttons (radio)',
      'a single box with its label: use a labeled control (control-field)',
      'grouped switches: use a switch group (switch-group)',
    ],
  ),
  'switch-group': (
    title: 'Switch group',
    description:
        'Gathers independent on/off settings under one label, description and '
        'error, such as alerts or sync options, read as one named group.',
    notFor: [
      'a single switch with its label: use a labeled control (control-field)',
      'several choices sent with the form: use a checkbox group '
          '(checkbox-group)',
      'a settings page as a list: use a list row (list-row)',
    ],
  ),
  'color-swatch-picker': (
    title: 'Color swatch picker',
    description:
        'Picks a shade from a palette the app provides, such as a product or '
        'label color: the chosen dot shrinks inside a ring and gets a check '
        'mark, and each dot is read by its name.',
    notFor: [
      'an option with a text label: use radio buttons (radio)',
      'a continuous value set by hand, such as an opacity: use a slider '
          '(slider)',
      'an option you check or uncheck: use a checkbox (checkbox)',
    ],
  ),
  'combo-box': (
    title: 'Combo box',
    description:
        'Suggests matches under a text field as you type, from a local list '
        'or a remote lookup, with loading, no-result and error states; '
        'arrow keys pick a suggestion while focus stays in the field.',
    notFor: [
      'a short list, without typing: use a select (select)',
      'filtering the results shown on the page: use a search field '
          '(search-field)',
      'free text, without suggestions: use a text field (text-field)',
    ],
  ),
  'drawer': (
    title: 'Drawer',
    description:
        'Opens a navigation panel from the side of the screen over a scrim, '
        'mirrored in right-to-left layouts, and closes by swipe, tap outside, '
        'Escape or back.',
    notFor: [
      'a sheet anchored at the bottom: use a bottom sheet (sheet)',
      'a question awaiting an answer: use a dialog (dialog)',
      'main navigation always visible: use a tab bar (tab-bar)',
    ],
  ),
  'badge': (
    title: 'Badge',
    description:
        'Flags an unread count, a short word or a status dot on the corner of '
        'an icon, an avatar or a tab, capped at 99+ and read out with what it '
        'marks.',
    notFor: [
      'a status or category in text only: use a chip (chip)',
      'short help shown on hover or long press: use a tooltip (tooltip)',
      'the progress of a task: use a progress indicator (progress)',
    ],
  ),
  'avatar-group': (
    title: 'Avatar group',
    description:
        'Groups the people of a conversation or a project into a row of '
        'overlapping avatars, with a +N counter past a maximum.',
    notFor: [
      'a single person: use an avatar (avatar)',
      'an unread count on an icon: use a badge (badge)',
    ],
  ),
  'page-indicator': (
    title: 'Page indicator',
    description:
        'Shows the current page of an onboarding or a carousel as dots whose '
        'active one stretches into a pill, bound to a page view, and lets '
        'people change page by touch.',
    notFor: [
      'sections of the same screen: use tabs (tabs)',
      'the progress of a task: use a progress indicator (progress)',
    ],
  ),
  'empty-state': (
    title: 'Empty state',
    description:
        'Explains why a list or a search has nothing to show, after an error or '
        'without a network, with an icon, a title, a text and up to two '
        'actions.',
    notFor: [
      'loading in progress: use a skeleton (skeleton)',
      'a brief message that disappears on its own: use a toast (toast)',
    ],
  ),
  'account-settings': (
    title: 'Account settings',
    description:
        'Groups the profile, security and notifications of an account, and '
        'lets the user delete it after a confirmation, with its loading, '
        'error and offline states.',
    notFor: [
      'a single settings row in an existing page: use a list row (list-row)',
      'a message when the list is empty: use an empty state (empty-state)',
      'a bank statement, line by line: use a transaction row (transaction-row)',
    ],
  ),
  'auth-header': (
    title: 'Access header',
    description:
        'Tells people which access screen they are on: the app mark or an '
        'icon, the title, the only announced heading, and a sentence on what '
        'to do, centered.',
    notFor: [
      'a large title at the top of an ordinary screen, with a back arrow: use '
          'an app bar (app-bar)',
      'the heading of a group of rows: use a section header (section-header)',
    ],
  ),
  'social-sign-in': (
    title: 'Provider sign-in',
    description:
        'Lets people sign in with Apple, Google or another identity provider: '
        'one outlined button per provider, in a column or a row of logos, '
        'under an "or" divider.',
    notFor: [
      'an ordinary action button: use a button (button)',
      'a line between two pieces of content: use a separator (separator)',
    ],
  ),
  'auth-form': (
    title: 'Access form',
    description:
        'Groups the fields of an access screen and its main button: autofill, '
        'a form frozen while sending, an alert on top, and the field and '
        'button kept above the keyboard.',
    notFor: [
      'a single text field: use a text field (text-field)',
      'a single link under a form, such as the legal notice: use a link '
          '(link-button)',
      'a box to accept the terms before sending the form: use a checkbox '
          '(checkbox)',
      'a code received by SMS or email: use a one-time code (input-otp)',
      'a complete sign-in screen: use the sign-in screen (sign-in)',
    ],
  ),
  'sign-in': (
    title: 'Sign in',
    description:
        'Lets people sign in with email and password or an identity provider, '
        'with forgotten password, rejected credentials, offline and the wait '
        'after too many attempts.',
    notFor: [
      'creating an account: use the sign-up screen (sign-up)',
      'resetting a forgotten password: use the forgot password screen '
          '(forgot-password)',
      'an access form in an existing screen: use the access form block '
          '(auth-form)',
    ],
  ),
  'sign-up': (
    title: 'Sign up',
    description:
        'Lets people create an account with name, email and a password whose '
        'rules are checked while typing, accept the terms, or use a provider; '
        'email taken and offline included.',
    notFor: [
      'a box to accept the terms before sending: use a checkbox (checkbox)',
      'signing in to an existing account: use the sign-in screen (sign-in)',
      'confirming the address with a received code: use the verification code '
          'screen (verify-code)',
      'an access form in an existing screen: use the access form block '
          '(auth-form)',
    ],
  ),
  'verify-code': (
    title: 'Verification code',
    description:
        'Lets people enter the six-digit code received by email or text '
        'message, with the masked destination, a resend countdown, a wrong '
        'or expired code and offline.',
    notFor: [
      'entering only a two-factor code in an existing form: use a one-time '
          'code (input-otp)',
      'creating an account before verifying its address: use the sign-up '
          'screen (sign-up)',
    ],
  ),
  'forgot-password': (
    title: 'Forgot password',
    description:
        'Lets people get an email link to choose a new password, then check '
        'their inbox, resend the link or go back to sign in, offline '
        'included.',
    notFor: [
      'signing in with a password: use the sign-in screen (sign-in)',
      'confirming an address with a code: use the verification code screen '
          '(verify-code)',
    ],
  ),
  'app-settings': (
    title: 'App settings',
    description:
        'Groups the settings of the app: appearance, text size, language, '
        'haptics, a cache to clear after a confirmation, version, licenses and '
        'legal notices, with a link to the account.',
    notFor: [
      'the signed-in account\'s profile and security: use the account screen '
          '(account-settings)',
      'a single switch in a page: use a list row (list-row)',
    ],
  ),
  'edit-profile': (
    title: 'Edit profile',
    description:
        'Lets people change the photo, name, username checked while typing '
        'and bio of their profile, and asks before discarding unsaved '
        'changes.',
    notFor: [
      'a single text field in a page: use a text field (text-field)',
      'account settings, security and deletion: use account settings '
          '(account-settings)',
    ],
  ),
  'notifications': (
    title: 'Notification center',
    description:
        'Groups received notifications by day, marks the unread ones and '
        'lets people mark all as read or refresh, with its empty, loading, '
        'error and offline states.',
    notFor: [
      'notification preferences (push, email): use account settings '
          '(account-settings)',
      'a brief message that disappears on its own: use a toast (toast)',
    ],
  ),
  'search': (
    title: 'Filtered search',
    description:
        'Searches products while people type, with a row of categories, '
        'advanced filters in a sheet, recent searches, results that load more '
        'as you scroll, and its empty, no results, error and offline states.',
    notFor: [
      'a single search field in an existing screen: use a search field '
          '(search-field)',
      'a no-results message inside a list: use an empty state (empty-state)',
    ],
  ),
  'product': (
    title: 'Product page',
    description:
        'Presents a product with its photo gallery, price, rating, color, '
        'size and quantity, a collapsible description and add to cart always '
        'in reach, with loading, sold out, error and offline states.',
    notFor: [
      'a product in a list of results: use a result card (result-card)',
      'a sequence of photos alone: use a page indicator (page-indicator)',
    ],
  ),
  'result-card': (
    title: 'Result card',
    description:
        'Presents a search result or a product with its thumbnail, name, '
        'price and a rating or delivery line, as a list row or a grid tile, '
        'and opens it on tap.',
    notFor: [
      'a settings or navigation row: use a list row (list-row)',
      'free content on a surface: use a card (card)',
    ],
  ),
  'settings-section': (
    title: 'List section',
    description:
        'Groups rows under a heading, with an optional link at the end of the '
        'heading: a topic of an account screen or a day of notifications.',
    notFor: [
      'a single row in a page: use a list row (list-row)',
      'a heading alone above a grid: use a section header (section-header)',
    ],
  ),
  'profile-card': (
    title: 'Account card',
    description:
        'Introduces the signed-in person above the topics of their account: '
        'avatar, name and address, and opens the account on tap.',
    notFor: [
      'a photo alone: use an avatar (avatar)',
      'a list of people: use a list row (list-row)',
    ],
  ),
  'confirm-delete': (
    title: 'Delete confirmation',
    description:
        'Asks to confirm a destructive action: an alert that says what will '
        'be erased, a red delete button and a button to back out.',
    notFor: [
      'a simple question before deleting an item from a list: use a dialog '
          '(dialog)',
      'a brief message that disappears on its own: use a toast (toast)',
    ],
  ),
  'conversation-row': (
    title: 'Conversation row',
    description:
        'Shows one conversation in a list: avatar or group of avatars, name, '
        'last message on two lines at most, its age, an unread count, muted and pinned '
        'marks, and its actions on long press.',
    notFor: [
      'a simple settings or list row: use a list row (list-row)',
      'the whole conversations screen: use the conversations list '
          '(conversations)',
    ],
  ),
  'message-bubble': (
    title: 'Message bubble',
    description:
        'Shows one message of a chat thread: sent at the end, received at the '
        'start, grouped by author, with the quoted reply, the time, and sending, '
        'sent, read or failed with retry.',
    notFor: [
      'a brief message that disappears on its own: use a toast (toast)',
      'a status message in a page: use an alert (alert)',
    ],
  ),
  'composer': (
    title: 'Message composer',
    description:
        'Lets people write a chat message: a pill input that grows up to a '
        'few lines, a send button in an accent circle enabled only with text, '
        'an attach slot, and the reply being written above it.',
    notFor: [
      'a form field with a label: use a text field (text-field)',
      'searching a list: use a search field (search-field)',
    ],
  ),
  'conversations': (
    title: 'Conversations',
    description:
        'Lists the conversations of a messaging app, pinned ones as avatars '
        'on top, with swipe actions, search, pull to refresh, a new message '
        'sheet, and its empty, loading, error and offline states.',
    notFor: [
      'the thread of a single discussion: use the chat thread (chat)',
      'received notifications: use the notification center (notifications)',
    ],
  ),
  'onboarding': (
    title: 'Onboarding',
    description:
        'Introduces the service on first launch in two to five illustrated '
        'pages that people swipe or skip, ending on a call to action and a '
        'link for people who already have an account.',
    notFor: [
      'the dots alone of a sequence of pages: use the page indicator '
          '(page-indicator)',
      'an empty page with an illustration and an action: use an empty state '
          '(empty-state)',
    ],
  ),
  'chat': (
    title: 'Chat thread',
    description:
        'Shows a conversation anchored at the bottom, grouped by author and '
        'day, with older messages loaded while scrolling up, optimistic '
        'sending with retry, typing, and copy, reply or delete.',
    notFor: [
      'the list of all discussions: use the conversations list (conversations)',
      'a comment thread under some content: compose message bubbles '
          '(message-bubble)',
    ],
  ),
  'plan-card': (
    title: 'Plan card',
    description:
        'Presents a subscription plan to pick among others, as a radio '
        'button: name, billed price and period, trial, perks, and the '
        'recommended and current plan marks.',
    notFor: [
      'a short choice without a price: use radio buttons (radio)',
      'the whole plans screen: use the plans screen (plans)',
    ],
  ),
  'cart-line': (
    title: 'Cart line',
    description:
        'Shows an item in a cart with its thumbnail, name, variant and '
        'price, a quantity stepper and remove, or a read-only summary on a '
        'past order.',
    notFor: [
      'a product in results: use a result card (result-card)',
      'a number set on its own: use a number field (number-field)',
    ],
  ),
  'order-summary': (
    title: 'Order summary',
    description:
        'Lists the amounts of an order, subtotal, shipping, discount and '
        'taxes, above the total, as given by the service, and hides them '
        'while they are recalculated.',
    notFor: [
      'a value row in a list: use a list row (list-row)',
      'a key figure on a dashboard: use a card (card)',
    ],
  ),
  'plans': (
    title: 'Plans and subscription',
    description:
        'Offers subscription plans with a monthly or yearly switch, plan '
        'cards, the current plan, a free trial, in-app purchase through the '
        'store, restore purchases and the terms.',
    notFor: [
      'a single plan to pick in a list: use radio buttons (radio)',
      'a cart of items to pay for: use the checkout screen (checkout)',
    ],
  ),
  'checkout': (
    title: 'Cart and checkout',
    description:
        'Shows the cart and pays for it: quantities, undoable removal, promo '
        'code, saved address and payment method in a sheet, the totals from '
        'the service and a single payment at a time.',
    notFor: [
      'a digital subscription: use the plans screen (plans)',
      'a single item to add: use the product page (product)',
    ],
  ),
  'order-confirmation': (
    title: 'Order confirmation',
    description:
        'Confirms a paid order with its number, estimated delivery, address, '
        'items and amounts paid, then tracking or home, with no way back to '
        'the payment.',
    notFor: [
      'the cart before payment: use the checkout screen (checkout)',
      'a list of past orders: use list rows (list-row)',
    ],
  ),
  'booking': (
    title: 'Stay booking',
    description:
        'Shows a holiday rental’s listing with photos, host, amenities and '
        'reviews, then books a stay around nights already taken, with guests '
        'and a price that follows the choice.',
    notFor: [
      'paying for a cart: use the checkout screen (checkout)',
      'a period in a form without prices or availability: use the date range '
          'picker (date-range-picker)',
    ],
  ),
  'track-row': (
    title: 'Track row',
    description:
        'Shows a song in a list with its artwork, title, artist and length '
        'spoken in words, the song now playing marked by bars that move, '
        'read as one node.',
    notFor: ['the whole library screen: use the music library (library)'],
  ),
  'mini-player': (
    title: 'Mini player',
    description:
        'Keeps the song now playing at the bottom of a screen: artwork, '
        'title and artist, a play or pause button that acts in place, and a '
        'dock that sets it on the accent above the tab bar.',
    notFor: ['the whole player screen: use the music player (player)'],
  ),
  'player': (
    title: 'Music player',
    description:
        'Plays a song from the app\'s audio player on the accent: artwork, '
        'title and artist, a position slider read in minutes and seconds, '
        'play and pause, next and previous, shuffle, repeat and favorite.',
    notFor: [
      'a list of tracks, albums or playlists: use the music library (library)',
      'setting a continuous value: use the slider (slider)',
    ],
  ),
  'library': (
    title: 'Music library',
    description:
        'Shows a listener\'s music: a search by title or artist, albums and '
        'playlists as shelves of artwork, songs page by page, and the song now '
        'playing on the accent at the bottom.',
    notFor: [
      'the player currently playing: use the music player (player)',
      'one album or one playlist and its songs: use the album and playlist '
          'screen (collection)',
      'a search in a product catalog: use the search screen (search)',
    ],
  ),
  'collection': (
    title: 'Album and playlist',
    description:
        'Shows an album or a playlist: its cover, title and artist, Play and '
        'Shuffle, then its songs, numbered on an album, and the song now '
        'playing on the accent at the bottom.',
    notFor: [
      'a listener\'s whole music: use the music library (library)',
      'the song now playing: use the music player (player)',
    ],
  ),
  'tracking-steps': (
    title: 'Tracking steps',
    description:
        'Shows where a delivery or a request stands as dated vertical '
        'steps, the current step written out in words and read with its '
        'rank by screen readers.',
    notFor: [
      'a bar that fills during a task: use a progress indicator (progress)',
      'the dots of a carousel or an onboarding: use a page indicator '
          '(page-indicator)',
    ],
  ),
  'order-row': (
    title: 'Order row',
    description:
        'Shows an order in a list with the photo of its first item, its '
        'number, date, item count and total, and its status written in '
        'words, read as one node.',
    notFor: [
      'a cart item with its quantity: use a cart line (cart-line)',
      'a payment or a bank transfer: use a transaction row (transaction-row)',
    ],
  ),
  'orders': (
    title: 'Order history',
    description:
        'Lists a customer\'s orders in two tabs, current and past, '
        'searchable by number or item, loaded page by page and refreshed '
        'by pulling.',
    notFor: [
      'the details and tracking of a purchase: use order tracking (order)',
      'a search in the catalog: use the search screen (search)',
    ],
  ),
  'order': (
    title: 'Order tracking',
    description:
        'Shows an order with its dated delivery steps, items, amounts paid '
        'and address, with a confirmed cancellation sent only once, returns '
        'and support.',
    notFor: [
      'the thank-you and receipt right after payment: use the order '
          'confirmation (order-confirmation)',
      'the list of all purchases: use the order history (orders)',
      'dated vertical steps on their own: use the tracking steps '
          '(tracking-steps)',
    ],
  ),
  'help-center': (
    title: 'Help center',
    description:
        'Shows frequently asked questions by topic in accordions, searchable '
        'without accents with the matching words in bold, a helpful or not '
        'vote on each answer, and readable offline.',
    notFor: [
      'a single collapsible topic in a screen: use an accordion (accordion)',
      'the request sent to support and its progress: use contact support '
          '(contact-support)',
    ],
  ),
  'contact-support': (
    title: 'Contact support',
    description:
        'Lets people write to support with a subject, a reference, a bounded '
        'message and attachments, sent only once even without an answer, then '
        'follow the request and read the latest reply.',
    notFor: [
      'frequently asked questions and their search: use the help center '
          '(help-center)',
      'tracking a purchase and its delivery: use order tracking (order)',
    ],
  ),
  'task-row': (
    title: 'Task row',
    description:
        'Shows a to-do with its checkbox, due day, priority and lateness '
        'written in words, read by screen readers as one checkbox node.',
    notFor: [
      'a single box in a form: use the checkbox (checkbox)',
      'an agenda event: use an event row (event-row)',
    ],
  ),
  'event-row': (
    title: 'Event row',
    description:
        'Shows an agenda event with the time it starts and the time it '
        'stops, its place, and the word now while it is happening, read as '
        'one node.',
    notFor: [
      'a task to check off: use a task row (task-row)',
      'a step of a delivery tracking: use the tracking steps (tracking-steps)',
      'the whole agenda for the day or week: use the agenda (agenda)',
      'a time typed on the keyboard in a form: use the time field (time-field)',
    ],
  ),
  'event-card': (
    title: 'Event card',
    description:
        'Shows an agenda event in its own card: the times it starts and '
        'ends in a column, its title, the word now while it is happening, '
        'and its place, description and attendees, read as one node.',
    notFor: [
      'an event in a grouped list with dividers: use the event row (event-row)',
      'the whole agenda for the day or week: use the agenda (agenda)',
      'a task to check off: use a task row (task-row)',
    ],
  ),
  'tasks': (
    title: 'Tasks',
    description:
        'Groups tasks into overdue, today, upcoming, undated and done, each '
        'with its checkbox, with a quick add line and a sheet to edit the '
        'due day and priority.',
    notFor: [
      'a single box in a form: use the checkbox (checkbox)',
      'the events of a day or a week: use the agenda (agenda)',
      'a single task to check off, with its due date and priority, placed '
          'elsewhere: use the task row (task-row)',
    ],
  ),
  'agenda': (
    title: 'Agenda',
    description:
        'Shows a month with a dot per event under each day, zooms into a '
        'day and out to the year, opens an event to edit or delete it, and '
        'creates events with place or video call, guests and files.',
    notFor: [
      'a month grid to pick a date: use the calendar (calendar)',
      'things to do, to check off: use the task list (tasks)',
      'a single appointment in another list: use the event row (event-row)',
    ],
  ),
  'tag-group': (
    title: 'Tag group',
    description:
        'Lets people pick tags among wrapping capsules, such as interests or '
        'filters, and remove them with their cross. Single or multiple '
        'selection, two backgrounds, three sizes.',
    notFor: [
      'a status shown without a choice: use a chip (chip)',
      'an exclusive choice in a form: use radio buttons (radio)',
    ],
  ),
  'close-button': (
    title: 'Close button',
    description:
        'Closes a dialog, a window, a popover or a menu: a round button with a '
        'cross, named for screen readers.',
    notFor: ['cancelling an action in progress: use a button (button)'],
  ),
  'control-field': (
    title: 'Labeled control',
    description:
        'Lets people tap the whole label of a switch, checkbox or radio: '
        'label, helper text and error message around the control.',
    notFor: [
      'a control alone, without a visible label: use a switch (switch), a '
          'checkbox (checkbox) or a radio button (radio)',
      'several exclusive options of the same choice: use a radio group (radio)',
    ],
  ),
  'field': (
    title: 'Field label, description and error',
    description:
        'Says what a field asks for, explains it and reports its error: label '
        'with a required asterisk, description, announced error message.',
    notFor: ['text input: use a text field (text-field)'],
  ),
  'select': (
    title: 'Select',
    description:
        'Offers one or several choices from a closed list, from a trigger that '
        'shows the current choice. A list as wide as the trigger, '
        'or a bottom sheet or a dialog.',
    notFor: [
      'triggering an action: use a menu (menu)',
      'two or three choices always visible: use radio buttons (radio)',
      'entering free text: use a text field (text-field)',
      'a city or an address to find by typing: use a combo box (combo-box)',
    ],
  ),
  'separator': (
    title: 'Separator',
    description:
        'Marks the limit between two rows, two blocks or two columns with a '
        'thin or thick line, sharp to the pixel.',
    notFor: ['space without a line: use the token spacing (core)'],
  ),
  'spinner': (
    title: 'Spinner',
    description:
        'Shows that something is loading with a spinning arc, in three sizes '
        'and four colors, still when motion is reduced.',
    notFor: ['measurable progress: use a progress bar (progress)'],
  ),
  'surface': (
    title: 'Surface',
    description:
        'Groups content on a raised, shadowed background with continuous '
        'corners: the base of cards, row groups and alerts.',
    notFor: ['a window over the page: use a dialog (dialog)'],
  ),
  'text': (
    title: 'Text',
    description:
        'Gives the headings, paragraphs and inline code of the type scale, in '
        'the regular or muted color.',
    notFor: ['text typed by the user: use a text field (text-field)'],
  ),
  'text-field': (
    title: 'Text field',
    description:
        'Takes a line or a paragraph of text: label, helper and announced '
        'error, required field, prefix, suffix, obscured input, text area and '
        'a cut, copy, paste toolbar.',
    notFor: [
      'offering suggestions under the field while typing: use a combo box '
          '(combo-box)',
    ],
  ),
  'input-group': (
    title: 'Input group',
    description:
        'Puts a prefix and a suffix around an input: an icon, a unit, a '
        'protocol or a button inside the field frame, the text between them.',
    notFor: [
      'showing a label, help or an error: use a text field (text-field)',
      'searching a list: use a search field (search-field)',
    ],
  ),
  'search-field': (
    title: 'Search field',
    description:
        'Searches or filters a list: a field with a magnifier, the search key '
        'of the keyboard and a button that clears the query.',
    notFor: [
      'entering text that is not a search: use a text field (text-field)',
      'picking a value among suggestions under the field: use a combo box '
          '(combo-box)',
    ],
  ),
  'input-otp': (
    title: 'One-time code',
    description:
        'Takes a code received by text message or email: one box per digit, '
        'in groups, a single field for screen readers, paste and the code the '
        'system suggests.',
    notFor: ['entering a password: use an obscured text field (text-field)'],
  ),
  'scroll-shadow': (
    title: 'Scroll shadow',
    description:
        'Fades the edges of a scrolling list into the page to show there is '
        'more to scroll, vertically or horizontally.',
    notFor: ['separating two fixed blocks: use a separator (separator)'],
  ),
  'skeleton': (
    title: 'Skeleton',
    description:
        'Holds the place of loading content with animated grey shapes, then '
        'fades the content in. Includes a single bone and a bone group.',
    notFor: [
      'waiting with no known shape: use a spinner (spinner)',
      'measurable progress: use a progress bar (progress)',
    ],
  ),
  'toast': (
    title: 'Toast',
    description:
        'Reports the result of an action with a short message at the top or '
        'bottom of the screen, stacked with the previous ones, closed by time, '
        'swipe or its button.',
    notFor: [
      'asking for confirmation before an irreversible action: use a dialog '
          '(dialog)',
      'explaining a control on hover or long press: use a tooltip (tooltip)',
      'reporting an input error in a form: use the field\'s error message '
          '(field)',
    ],
  ),
  'tooltip': (
    title: 'Tooltip',
    description:
        'Explains an icon or a control on hover, long press or keyboard focus, '
        'and closes on Escape. An anchored bubble, read by screen '
        'readers.',
    notFor: [
      'rich or interactive anchored content: use a popover (popover)',
      'a list of actions: use a menu (menu)',
      'a label always visible under a field: use a text field (text-field)',
    ],
  ),
  'app-bar': (
    title: 'App bar',
    description:
        'Shows where the user is and leads back: the screen title, a back '
        'chevron and up to three actions, with a large title that collapses '
        'into the bar on scroll.',
    notFor: [
      'the title of a section in the page: use a section header '
          '(section-header)',
      'navigation between the app\'s sections: use the tab bar (tab-bar)',
    ],
  ),
  'tab-bar': (
    title: 'Tab bar',
    description:
        'Switches between the main sections of an app from the bottom of the '
        'screen: three to five tabs with icon, label and badge, on a docked, '
        'translucent or floating bar.',
    notFor: [
      'views of the same screen: use tabs (tabs)',
      'a screen\'s actions: use the app bar (app-bar)',
      'navigation tucked into a side panel: use a drawer (drawer)',
    ],
  ),
  'page': (
    title: 'Page',
    description:
        'Frames a whole mobile screen: safe areas, an app bar tied to '
        'scrolling, scrolling content, a tab bar, the keyboard and pull to '
        'refresh with each platform gesture.',
    notFor: ['a window laid over the screen: use a bottom sheet (sheet)'],
  ),
  'section-header': (
    title: 'Section header',
    description:
        'Names the group of rows or the grid below it: a muted title aligned '
        'with the group, and an optional see all link.',
    notFor: ['the screen\'s title: use the app bar (app-bar)'],
  ),
  'chart': (
    title: 'Chart',
    description:
        'Plots one or two series over time as bars or a line, shows the value '
        'of a point on touch, drag or arrow keys, reads a summary and every '
        'point to screen readers, and offers the same data as a table.',
    notFor: [
      'progress of a task toward a goal: use a progress indicator (progress)',
      'a single key figure with its change: use a stat card (stat-card)',
      'picking a day in a date grid: use a calendar (calendar)',
    ],
  ),
  'stat-card': (
    title: 'Stat card',
    description:
        'Shows a key figure such as a balance in large type, with its change '
        'in a signed pill, a short note and an optional action to hide it.',
    notFor: [
      'progress toward a goal: use a progress indicator (progress)',
      'change over time: use a chart (chart)',
    ],
  ),
  'transaction-row': (
    title: 'Transaction row',
    description:
        'Shows one transaction in a list: avatar, merchant, category and '
        'time, and the signed amount, readable without color, with its '
        'direction spoken to screen readers.',
    notFor: [
      'a simple settings or list row: use a list row (list-row)',
      'an item in a cart: use a result card (result-card)',
    ],
  ),
  'finance-dashboard': (
    title: 'Finance dashboard',
    description:
        'Shows the balance that can be hidden, spending for the week, month or '
        'year as a chart or a table, savings goals and the latest '
        'transactions by day, with loading, empty, error and offline states.',
    notFor: [
      'a single key figure card: use a stat card (stat-card)',
      'a chart alone: use a chart (chart)',
    ],
  ),
  'post-card': (
    title: 'Post card',
    description:
        'Shows one post of a social feed: author and place, a carousel of up '
        'to ten photos that open full screen, double tap to like, comments, '
        'share, bookmark, who liked it and a caption.',
    notFor: [
      'a product with its price: use a result card (result-card)',
      'a message in a discussion: use a message bubble (message-bubble)',
    ],
  ),
  'comment-row': (
    title: 'Comment row',
    description:
        'Shows one comment under a post: avatar, name, age and text, replies '
        'indented on a single level, posting or failed with retry, and its '
        'actions as links.',
    notFor: [
      'a message in a private discussion: use a message bubble '
          '(message-bubble)',
      'a whole post with its images: use a post card (post-card)',
    ],
  ),
  'feed': (
    title: 'Social feed',
    description:
        'Shows stories that play full screen, then flat posts with a photo '
        'carousel, optimistic likes and saves, hide or report with undo, new '
        'posts on demand, and an optional For you feed.',
    notFor: [
      'a list of products with their prices: use the filtered search (search)',
      'the messages of a discussion: use the chat thread (chat)',
    ],
  ),
  'post': (
    title: 'Post and comments',
    description:
        'Shows one post with its paged comments and one level of replies, a '
        'composer that posts in order without waiting, retry, and deleting '
        'your own comments after confirmation.',
    notFor: [
      'a private conversation: use the chat thread (chat)',
      'a list of posts: use the social feed (feed)',
      'a single comment row: use a comment row (comment-row)',
    ],
  ),
  'profile': (
    title: 'Public profile',
    description:
        'Shows someone’s public page: avatar, bio and short counters, an '
        'optimistic Follow toggle or Edit profile for yourself, then posts as '
        'a list and media as a grid.',
    notFor: [
      'the user\'s account settings: use account settings (account-settings)',
      'the form that changes the name or photo: use edit profile '
          '(edit-profile)',
    ],
  ),
  'kbd': (
    title: 'Keyboard key',
    description:
        'Shows a key or a shortcut to type on a keyboard, such as ⌘ K: '
        'Apple symbols on iOS and macOS, Ctrl or Alt elsewhere, on a key cap '
        'or bare.',
    notFor: [
      'a status or category label: use a chip (chip)',
      'a counter on an icon: use a badge (badge)',
    ],
  ),
  'meter': (
    title: 'Meter',
    description:
        'Shows a quantity within a known range, such as storage used or '
        'battery: label, value and a filled track, in three sizes and five '
        'colors.',
    notFor: [
      'a task under way, an upload: use the progress indicator (progress)',
      'a value the user sets: use the slider (slider)',
      'a key figure with its trend: use the stat card (stat-card)',
    ],
  ),
  'toggle-button': (
    title: 'Toggle button',
    description:
        'Turns an option on or off with one button that stays pressed, such '
        'as a favorite or an editor\'s bold: with text or an icon alone, '
        'filled or ghost.',
    notFor: [
      'one exclusive choice among several options: use the segmented '
          'control (segmented)',
      'a setting switched on or off in a list: use a switch (switch)',
      'a one-off action: use a button (button)',
    ],
  ),
  'button-group': (
    title: 'Button group',
    description:
        'Joins related actions into one bar of attached buttons, such as '
        'copy, paste and cut: rounded only at both ends, hairlines between '
        'the buttons.',
    notFor: [
      'a single choice among several options: use the segmented control '
          '(segmented)',
      'a toolbar with keyboard navigation: use the toolbar (toolbar)',
      'a single action: use a button (button)',
    ],
  ),
  'fieldset': (
    title: 'Fieldset',
    description:
        'Gathers fields that belong together under a title, such as an '
        'address or a profile: legend, the group\'s description or error, '
        'spaced fields and action buttons.',
    notFor: [
      'a single field with its label and message: use the field (field)',
      'a section of settings rows: use the settings section '
          '(settings-section)',
      'a whole sign-in form: use the auth form (auth-form)',
    ],
  ),
  'breadcrumbs': (
    title: 'Breadcrumbs',
    description:
        'Shows where the current page sits in a hierarchy and goes back up a '
        'level: pressable levels between chevrons, on one line that scrolls '
        'and cuts long names.',
    notFor: [
      'a title bar with a back button: use the app bar (app-bar)',
      'tabs between sibling views: use tabs (tabs)',
      'the steps of a process to follow: use the tracking steps '
          '(tracking-steps)',
    ],
  ),
  'pagination': (
    title: 'Pagination',
    description:
        'Moves from one page of results to another: previous, numbers with '
        'ellipses, next, and a summary; compact on a phone, it folds what '
        'does not fit.',
    notFor: [
      'the dots of a carousel or an onboarding: use the page indicator '
          '(page-indicator)',
      'a list that loads as it scrolls: use a list row (list-row)',
    ],
  ),
  'toolbar': (
    title: 'Toolbar',
    description:
        'Gathers the commands that act on the same content in one bar, '
        'floating or not, such as text formatting: the arrow keys move from '
        'one button to the next.',
    notFor: [
      'the main navigation between screens: use the tab bar (tab-bar)',
      'a screen\'s title and actions: use the app bar (app-bar)',
      'attached actions without a bar: use the button group (button-group)',
    ],
  ),
  'color-swatch': (
    title: 'Color swatch',
    description:
        'Shows a color the app picked in a round or square swatch, over a '
        'checkerboard that shows through a translucent tint. Screen readers '
        'read its name.',
    notFor: [
      'picking a shade from a palette: use a color swatch picker '
          '(color-swatch-picker)',
      'setting any color freely: use a color picker (color-picker)',
      'a status dot next to an avatar: use a badge (badge)',
    ],
  ),
  'color-slider': (
    title: 'Color slider',
    description:
        'Sets one channel of a color, hue, saturation, brightness, lightness '
        'or opacity, on a track painted with the colors it goes through.',
    notFor: [
      'a value that is not a color, such as a volume: use a slider (slider)',
      'saturation and brightness together: use a color area (color-area)',
      'a full choice with the area and the code: use a color picker '
          '(color-picker)',
    ],
  ),
  'color-area': (
    title: 'Color area',
    description:
        'Sets two channels of a color at once on a gradient square, '
        'saturation and brightness under the chosen hue by default.',
    notFor: [
      'a single channel, such as the hue: use a color slider (color-slider)',
      'one color among a few shades: use a color swatch picker '
          '(color-swatch-picker)',
      'a full choice in a panel: use a color picker (color-picker)',
    ],
  ),
  'color-field': (
    title: 'Color field',
    description:
        'Types a color as a hex code, with its swatch at the start of the '
        'field; a code that is not a color gives the previous one back on '
        'leaving.',
    notFor: [
      'free text: use a text field (text-field)',
      'picking a color by eye: use a color picker (color-picker)',
      'a number with minus and plus: use a number field (number-field)',
    ],
  ),
  'color-picker': (
    title: 'Color picker',
    description:
        'Opens, under a swatch and its label, the color area, the hue '
        'slider, opacity, the hex code and presets, all in sync.',
    notFor: [
      'a shade from a fixed palette: use a color swatch picker '
          '(color-swatch-picker)',
      'a code typed on the keyboard only: use a color field (color-field)',
      'a color shown without changing it: use a color swatch (color-swatch)',
    ],
  ),
  'table': (
    title: 'Data table',
    description:
        'Presents rows of data in columns: sort by header, selection, empty '
        'and loading states. On a phone it scrolls sideways with the first '
        'column held, or stacks each row.',
    notFor: [
      'a list of settings or contacts: use a list row (list-row)',
      'one figure in the spotlight: use a stat card (stat-card)',
      'values over time: use a chart (chart)',
    ],
  ),
};
