import QtQuick

import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n

/** What the energy of a period was worth: saved, earned and paid. */
Label {
    id: line

    /** money() of code/chart.mjs, null when no price is set. */
    required property var amounts
    required property string currency
    required property string language
    /** `{ text, secondary }`, see `scheme` in FullRepresentation. */
    required property var scheme

    visible: amounts !== null
    relativeSize: 0.82
    wrapMode: Text.WordWrap
    color: scheme.secondary
    text: amounts === null ? "" : ["saved", "earned", "paid"].map(name => `${I18n.t(line.language, `money.${name}`)} ${Format.money(line.amounts[name], line.currency, line.language)}`).join(" · ")
}
