

-- the procedures creates a temporary table consisting of customer behavior in the latest period of time
-- the sequence column retrieved from sp_customer_pattern table denotes the buying patterns of a customer in a certain period of time
-- the recency column denotes the last month in which the customer paid for the product
-- the continuity column denotes the no of months the customer continuously purchased the product
-- the max_length column returns the maximum length of the customer purchasing the product continuously



-- function to return max_length of each sequence to be called in the combined_pattern procedure
DELIMITER //
CREATE FUNCTION sw_001_extenso.get_max_len(seq VARCHAR(255)) RETURNS INT
DETERMINISTIC
NO SQL
BEGIN
    DECLARE len INT;
    DECLARE i INT DEFAULT 1;
    DECLARE new CHAR(1);
    DECLARE max_len INT DEFAULT 0;
    DECLARE curr_len INT DEFAULT 0;

    SET len = CHAR_LENGTH(seq);
    SET i = 1;

    recency_loop: WHILE i <= len DO
        SET new = SUBSTRING(seq, i, 1);
        IF new = '1' THEN
            SET curr_len = curr_len + 1;
            IF curr_len > max_len THEN
                SET max_len = curr_len;
            END IF;
        ELSE
            SET curr_len = 0;
        END IF;
        SET i = i + 1;
    END WHILE recency_loop;

    RETURN max_len;
END //

DELIMITER ;



-- procedure to create the customer purchasing_pattern
DELIMITER //
CREATE PROCEDURE sw_001_extenso.purchasing_pattern()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE seq VARCHAR(255);
    DECLARE rev_seq VARCHAR(255);

    DECLARE max_length INT;

    DECLARE i INT DEFAULT 1;
    DECLARE len INT;
    DECLARE new CHAR(1);
    DECLARE count INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT sequence FROM sw_001_extenso.sp_customer_pattern;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=TRUE;

    -- Create a temporary table to hold the results
    CREATE TABLE IF NOT EXISTS purchasing_pattern (
        id INT AUTO_INCREMENT PRIMARY KEY ,
        recency_count INT,
        continuity INT,
        max_length INT
    );

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO seq;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Call the user-defined function to get the max length of consecutive '1's
        SET max_length = sw_001_extenso.get_max_len(seq);

        SET rev_seq = REVERSE(seq);
        SET len = CHAR_LENGTH(rev_seq);
        SET count = 0;
        SET i = 1;

        -- Reset recency count
        SET @recency_count = 0;

        recency_loop: WHILE i <= len DO
            SET new = SUBSTRING(rev_seq, i, 1);
            IF new = '1' THEN
                IF @recency_count = 0 THEN
                    SET @recency_count = i;
                END IF;
                SET count = count + 1;
            ELSE
                IF @recency_count > 0 THEN
                        LEAVE recency_loop;
                END IF;
            END IF;
            SET i = i + 1;
        END WHILE recency_loop;

        INSERT INTO purchasing_pattern (recency_count, continuity, max_length) VALUES (@recency_count, count, max_length);
    END LOOP;

    CLOSE cur;

    SELECT * FROM purchasing_pattern;
#     DROP TEMPORARY TABLE recency_pattern;
END //
DELIMITER ;

CALL sw_001_extenso.purchasing_pattern();

DROP PROCEDURE sw_001_extenso.purchasing_pattern;

DROP TABLE sw_001_extenso.purchasing_pattern;