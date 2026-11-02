"""BPI text parser used by the optional FastAPI service.

The Flutter app uses the layout-aware Dart implementation. This module applies
the same business rules to plain page text so the service stays deterministic
and free of paid AI APIs.
"""

from __future__ import annotations

import re
from datetime import date

MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11,
    "december": 12,
}

TX = re.compile(
    r"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+"
    r"(\d{1,2})\s+"
    r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+"
    r"(\d{1,2})\s+"
    r"(.+?)\s+"
    r"(-?[\d,]+\.\d{2})$",
    re.I,
)
TX_NO_AMT = re.compile(
    r"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+"
    r"(\d{1,2})\s+"
    r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+"
    r"(\d{1,2})\s+"
    r"(.+)$",
    re.I,
)
FX = re.compile(r"(U\.?S\.?\s*Dollar|USD)\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})", re.I)
INST = re.compile(r"\s*:?\s*(\d{1,2})\s*/\s*(\d{1,2})\s*$")
CARD = re.compile(r"^(\d{4,6}-\d-\d{2}-\d+)\s*-\s*(.+)$")
SUMMARY = re.compile(r"^(\d{6})\s+(\d{6})\s+(.+?)\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})$")


def _money(text: str) -> float:
    return float(text.replace(",", ""))


def _date(month: str, day: str, year: int, statement_month: int) -> str:
    m = MONTHS[month.lower()]
    y = year - 1 if statement_month <= 2 and m >= 11 else year
    return date(y, m, int(day)).isoformat()


def parse_bpi_text(text: str) -> dict:
    lines = [re.sub(r"\s+", " ", raw).strip() for raw in text.splitlines() if raw.strip()]
    statement_date = None
    for line in lines:
        if "STATEMENT DATE" in line.upper():
            match = re.search(
                r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})",
                line,
                re.I,
            )
            if match:
                statement_date = date(int(match.group(3)), MONTHS[match.group(1).lower()], int(match.group(2)))
    year = statement_date.year if statement_date else date.today().year
    month = statement_date.month if statement_date else date.today().month

    out: list[dict] = []
    summaries: list[dict] = []
    in_tx = False
    in_summary = False
    in_installment_purchase = False
    pending = None
    current_card = None
    cardholders: list[dict] = []

    for line in lines:
        lower = line.lower()
        if "installment balance summary" in lower:
            in_summary = True
            in_tx = False
            in_installment_purchase = False
            continue
        if "transaction" in lower and "post" in lower and "description" in lower:
            in_tx = True
            continue
        section = lower.replace(":", "").strip()
        if section in {"installment purchase", "installment purchases"}:
            in_installment_purchase = True
            in_tx = True
            continue
        if section in {"purchases", "retail purchases", "payments", "credits"}:
            in_installment_purchase = False
            continue
        if lower.startswith("installment amortization"):
            in_installment_purchase = False
            continue
        card = CARD.match(line)
        if card:
            current_card = card.group(2).title()
            cardholders.append({"display_name": current_card, "masked": "****"})
            in_tx = True
            in_installment_purchase = False
            continue
        if in_summary:
            row = SUMMARY.match(line)
            if row:
                summaries.append(
                    {
                        "merchant": row.group(3),
                        "original_amount": _money(row.group(4)),
                        "remaining_balance": _money(row.group(5)),
                    }
                )
            continue
        if not in_tx:
            continue
        if pending is not None:
            fx = FX.search(line)
            if fx:
                pending["amount"] = _money(fx.group(3))
                pending["original_currency"] = "USD"
                pending["original_amount"] = _money(fx.group(2))
                out.append(pending)
                pending = None
                continue
            out.append(pending)
            pending = None
        match = TX.match(line) or TX_NO_AMT.match(line)
        if not match:
            continue
        description = match.group(5).strip()
        amount = _money(match.group(6)) if match.lastindex and match.lastindex >= 6 and TX.match(line) else None
        inst = INST.search(description)
        detected = "purchase"
        if "payment" in description.lower() and "thank you" in description.lower():
            detected = "payment"
            in_installment_purchase = False
        elif "reversal" in description.lower() or "refund" in description.lower():
            detected = "refund"
            in_installment_purchase = False
        elif in_installment_purchase:
            detected = "installment_purchase"
        elif inst:
            detected = "installment_charge"
            description = INST.sub("", description).strip()
        if amount is None:
            pending = {
                "transaction_date": _date(match.group(1), match.group(2), year, month),
                "post_date": _date(match.group(3), match.group(4), year, month),
                "description": description,
                "detected_type": detected,
                "cardholder": current_card,
            }
            continue
        out.append(
            {
                "transaction_date": _date(match.group(1), match.group(2), year, month),
                "post_date": _date(match.group(3), match.group(4), year, month),
                "description": description,
                "amount": amount,
                "detected_type": detected,
                "installment_number": int(inst.group(1)) if inst else None,
                "total_installments": int(inst.group(2)) if inst else None,
                "cardholder": current_card,
            }
        )

    return {
        "bank_name": "BPI",
        "statement_date": statement_date.isoformat() if statement_date else None,
        "cardholders": cardholders,
        "lines": out,
        "installment_summaries": summaries,
    }
