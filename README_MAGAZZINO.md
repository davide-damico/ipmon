# Software Gestione Magazzino (CLI)

Questo progetto include anche un piccolo software da terminale per gestire un magazzino con database SQLite.

## Requisiti
- Python 3.9+

## Comandi principali

```bash
python3 magazzino.py aggiungi SKU001 "Mouse USB" 20 12.9 A1
python3 magazzino.py movimento SKU001 -2
python3 magazzino.py movimento SKU001 10
python3 magazzino.py elenco
python3 magazzino.py elimina SKU001
```

## Note
- Il database viene creato automaticamente nel file `magazzino.db`.
- Il comando `movimento` usa:
  - valori positivi per registrare carico
  - valori negativi per registrare scarico
