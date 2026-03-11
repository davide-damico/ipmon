#!/usr/bin/env python3
"""Software semplice per la gestione del magazzino via riga di comando."""

from __future__ import annotations

import argparse
import sqlite3
from dataclasses import dataclass
from pathlib import Path

DB_PATH = Path("magazzino.db")


@dataclass
class Prodotto:
    codice: str
    nome: str
    quantita: int
    prezzo: float
    scaffale: str


class Magazzino:
    def __init__(self, db_path: Path = DB_PATH) -> None:
        self.db_path = db_path
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_path)

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS prodotti (
                    codice TEXT PRIMARY KEY,
                    nome TEXT NOT NULL,
                    quantita INTEGER NOT NULL DEFAULT 0,
                    prezzo REAL NOT NULL DEFAULT 0,
                    scaffale TEXT NOT NULL DEFAULT 'N/A'
                )
                """
            )

    def aggiungi(self, prodotto: Prodotto) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO prodotti (codice, nome, quantita, prezzo, scaffale)
                VALUES (?, ?, ?, ?, ?)
                """,
                (prodotto.codice, prodotto.nome, prodotto.quantita, prodotto.prezzo, prodotto.scaffale),
            )

    def carico_scarico(self, codice: str, delta: int) -> None:
        with self._connect() as conn:
            cur = conn.execute("SELECT quantita FROM prodotti WHERE codice = ?", (codice,))
            row = cur.fetchone()
            if row is None:
                raise ValueError(f"Prodotto con codice '{codice}' non trovato")
            nuova_quantita = row[0] + delta
            if nuova_quantita < 0:
                raise ValueError("Operazione non valida: la quantità diventerebbe negativa")
            conn.execute("UPDATE prodotti SET quantita = ? WHERE codice = ?", (nuova_quantita, codice))

    def elimina(self, codice: str) -> None:
        with self._connect() as conn:
            cur = conn.execute("DELETE FROM prodotti WHERE codice = ?", (codice,))
            if cur.rowcount == 0:
                raise ValueError(f"Prodotto con codice '{codice}' non trovato")

    def elenco(self) -> list[Prodotto]:
        with self._connect() as conn:
            cur = conn.execute(
                "SELECT codice, nome, quantita, prezzo, scaffale FROM prodotti ORDER BY nome ASC"
            )
            return [Prodotto(*row) for row in cur.fetchall()]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gestione magazzino da terminale")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_add = sub.add_parser("aggiungi", help="Aggiunge un nuovo prodotto")
    p_add.add_argument("codice")
    p_add.add_argument("nome")
    p_add.add_argument("quantita", type=int)
    p_add.add_argument("prezzo", type=float)
    p_add.add_argument("scaffale")

    p_mov = sub.add_parser("movimento", help="Registra carico/scarico")
    p_mov.add_argument("codice")
    p_mov.add_argument("delta", type=int, help="Usa numeri positivi per carico, negativi per scarico")

    p_del = sub.add_parser("elimina", help="Elimina un prodotto")
    p_del.add_argument("codice")

    sub.add_parser("elenco", help="Mostra tutti i prodotti")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    magazzino = Magazzino()

    try:
        if args.cmd == "aggiungi":
            magazzino.aggiungi(
                Prodotto(args.codice, args.nome, args.quantita, args.prezzo, args.scaffale)
            )
            print("Prodotto aggiunto con successo")
        elif args.cmd == "movimento":
            magazzino.carico_scarico(args.codice, args.delta)
            print("Movimento registrato")
        elif args.cmd == "elimina":
            magazzino.elimina(args.codice)
            print("Prodotto eliminato")
        elif args.cmd == "elenco":
            prodotti = magazzino.elenco()
            if not prodotti:
                print("Magazzino vuoto")
                return
            print(f"{'CODICE':<12} {'NOME':<25} {'QTA':>6} {'PREZZO':>10} {'SCAFFALE':<10}")
            print("-" * 70)
            for p in prodotti:
                print(f"{p.codice:<12} {p.nome:<25} {p.quantita:>6} {p.prezzo:>10.2f} {p.scaffale:<10}")
    except sqlite3.IntegrityError:
        print("Errore: esiste già un prodotto con lo stesso codice")
    except ValueError as exc:
        print(f"Errore: {exc}")


if __name__ == "__main__":
    main()
