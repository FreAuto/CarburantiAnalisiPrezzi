-- =====================================================================
--  01_crea_database.sql – Prezzi dei carburanti in Italia ⛽
--  Crea le tabelle del database (SQLite).
--  Lo usa 02_carica_dati.py: non serve lanciarlo a mano.
-- =====================================================================

DROP VIEW  IF EXISTS v_prezzi;
DROP TABLE IF EXISTS prezzi;
DROP TABLE IF EXISTS impianti;
DROP TABLE IF EXISTS regioni;

-- 🗺️ le 20 regioni e la zona d'Italia
CREATE TABLE regioni (
    regione  TEXT PRIMARY KEY,
    zona     TEXT NOT NULL CHECK (zona IN ('Nord', 'Centro', 'Sud', 'Isole'))
);

-- ⛽ un distributore per riga
CREATE TABLE impianti (
    id_impianto  INTEGER PRIMARY KEY,
    marchio      TEXT,
    gestore      TEXT,
    tipo_strada  TEXT CHECK (tipo_strada IN ('Stradale', 'Autostradale')),
    comune       TEXT,
    provincia    TEXT,
    regione      TEXT REFERENCES regioni (regione),
    latitudine   REAL,
    longitudine  REAL
);

-- 💶 un prezzo per riga: giorno, distributore, carburante, self o servito
CREATE TABLE prezzi (
    data         TEXT    NOT NULL,              -- 'AAAA-MM-GG'
    id_impianto  INTEGER NOT NULL REFERENCES impianti (id_impianto),
    carburante   TEXT    NOT NULL CHECK (carburante IN ('Benzina', 'Gasolio', 'GPL', 'Metano')),
    modalita     TEXT    NOT NULL CHECK (modalita IN ('Self', 'Servito')),
    prezzo       REAL    NOT NULL CHECK (prezzo > 0),
    PRIMARY KEY (data, id_impianto, carburante, modalita)
) WITHOUT ROWID;

CREATE INDEX idx_prezzi_carburante ON prezzi (carburante, modalita, data);
CREATE INDEX idx_impianti_provincia ON impianti (provincia);

-- 👀 vista comoda: ogni prezzo con i dati del distributore
CREATE VIEW v_prezzi AS
SELECT p.data, p.carburante, p.modalita, p.prezzo,
       i.id_impianto, i.marchio, i.tipo_strada, i.comune, i.provincia, i.regione, r.zona
FROM prezzi p
JOIN impianti i ON i.id_impianto = p.id_impianto
JOIN regioni  r ON r.regione = i.regione;
