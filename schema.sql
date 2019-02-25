DROP   TABLE IF EXISTS jp_postcode.postcode;
CREATE TABLE jp_postcode.postcode (
    postcode7             int(7)    ZEROFILL NOT NULL,
    state                 varchar(100)   NOT NULL,
    city                  varchar(100)   NOT NULL,
    street                varchar(100)   NOT NULL,
    state_kana            varchar(100)   NOT NULL,
    city_kana             varchar(100)   NOT NULL,
    street_kana           varchar(100)   NOT NULL,
    created_at            int            NOT NULL
);
