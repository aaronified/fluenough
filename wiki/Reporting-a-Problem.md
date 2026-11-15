# Reporting a problem

The small report icon at the top of most screens, and on cards, opens a form. Its tooltip says "Get support or report a problem". The form knows which screen or card you came from.

## Choose what you need

| Choice | What happens |
|---|---|
| Support | A question, or help with the app. Sent by mail. It stays private. It never becomes a public issue. |
| Bug | Something went wrong. Becomes a public GitHub issue. |
| Feedback | An idea or a wish. Becomes a public GitHub issue. |

The form asks a few questions: for a bug, what you did, what happened, and what you expected. For feedback, what would help you and how.

## What is sent

Always sent: the screen and what it showed. You can also include device information. You can attach the app log: up to the last 7 days of screens opened, decks loaded, imports, warnings and errors. It never holds your answers or cards.

## How it is sent

- **By mail** (support). Your mail app opens with everything filled in. Change anything, then send it. If no mail app can take it, the app says so. If you attached no log, you can export the log from Settings > App log and attach it yourself.
- **On GitHub** (bugs and feedback). GitHub opens a new issue with the screen filled in. Issues are public, so leave out anything private. If GitHub cannot be opened, the link is copied.

Your email address is not shown on a public issue.

## Filing an issue yourself

You can open an issue at [github.com/aaronified/fluenough/issues](https://github.com/aaronified/fluenough/issues). Include the device and Android version, the app version, the deck, and the drill. For silent audio, say whether you used a phone, an emulator or Waydroid. Waydroid has no Google Play Services, so listening is silent there, and that is not a bug. Check that a voice for the language is installed. See [Speaking and listening](Speaking-and-Listening).

## Mistakes in a deck

If you speak the language, a wrong word or meaning is worth reporting. Use the report icon on the card, or see [Reviewing guide](Reviewing-Guide) to check whole decks.

Design: [ADR-0021](ADR-0021-In-App-Reports).

See also: [Learner guide](Learner-Guide), [Contributing](Contributing), [Home](Home).
