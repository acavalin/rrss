PRAGMA encoding = "UTF-8";
CREATE TABLE feeds (
  name          VARCHAR(255)  PRIMARY KEY,
  last_update   DATETIME      DEFAULT '2000-01-01 00:00:00',
  favicon       TEXT          DEFAULT ''  -- in Data_URI_scheme‎ (base64)
);

-- -----------------------------------------------------------------------------

PRAGMA page_size=8192;
PRAGMA encoding = "UTF-8";
CREATE TABLE items (
  id            INTEGER       PRIMARY KEY AUTOINCREMENT,
  hash_id       CHAR(128)     NOT NULL UNIQUE, -- SHA512 hash of link
  -- item data
  link          VARCHAR(1024) NOT NULL DEFAULT '',
  title         VARCHAR(1024) NOT NULL DEFAULT '',
  guid          VARCHAR(1024) NOT NULL DEFAULT '',
  content       TEXT          NOT NULL,
  pub_date      DATETIME      NOT NULL,
  -- item metadata
  read          BOOLEAN       DEFAULT 0,
  kept          BOOLEAN       DEFAULT 0,
  modified      BOOLEAN       DEFAULT 0,
  comment       VARCHAR(1024) DEFAULT ''
);
