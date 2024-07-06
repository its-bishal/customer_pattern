

-- procedure to create customer pattern between the passed dates as start date and end date
-- firstly creates a table customer_pattern with monthly columns representing if the customer has bought particular item in the week
-- then using the customer_pattern table, creates a sequence of the pattern in the sequence column of the new table sp_customer_pattern

DELIMITER //
CREATE PROCEDURE sw_001_extenso.sp_customer_pattern(sdate DATE, edate DATE)
BEGIN
    -- Add monthly_date column
    ALTER TABLE sw_001_extenso.rw_transaction_data
        ADD COLUMN monthly_date DATE;
    UPDATE sw_001_extenso.rw_transaction_data SET monthly_date = DATE_FORMAT(created_date, '%Y-%m-01');

    SET @sql = '';
    SET @concat_date = '';

    date_loop: LOOP
        -- End the loop when the date exceeds the end date
        IF sdate > edate THEN
            LEAVE date_loop;
        END IF;

        -- Generate dynamic SQL for the month
        SELECT GROUP_CONCAT(DISTINCT CONCAT(
                'MAX(CASE WHEN trans.monthly_date = ''', sdate, ''' THEN 1 ELSE 0 END) AS `', sdate, '`'))
        INTO @sql_part
        FROM sw_001_extenso.rw_transaction_data;

        -- Append the result to @sql
        SET @sql = CONCAT(@sql, IF(@sql != '', ', ', ''), @sql_part);

        -- retrieves the unique concatenated columns of the dates
        SET @concat_date = concat(@concat_date, if(length(@concat_date)>0,',',''),'`',sdate,'`');

        SET sdate = DATE_ADD(sdate, INTERVAL 1 MONTH);


    END LOOP;
    -- SELECT concat_date;

    -- Debugging: Check the generated SQL
    SELECT @sql;

    -- Create the customer_pattern table dynamically
    SET @sql_table = CONCAT(
        'CREATE TABLE IF NOT EXISTS customer_pattern AS
        SELECT trans.payer_account_id, prod.product_name, ', @sql, '
        FROM sw_001_extenso.rw_transaction_data AS trans
        JOIN sw_001_extenso.product_category_map AS prod
        USING (module_id, product_id, product_type_id)
        GROUP BY trans.payer_account_id, prod.product_name'
    );

    -- Prepare and execute the dynamic SQL
    PREPARE stmt FROM @sql_table;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Create sp_customer_pattern with sequence column
        SET @pattern_query = CONCAT(
        'CREATE TABLE IF NOT EXISTS sw_001_extenso.sp_customer_pattern AS
        SELECT sw_001_extenso.customer_pattern.*, CONCAT(', @concat_date, ') AS sequence
        FROM customer_pattern'
    );

    select @pattern_query;

    -- Prepare and execute the dynamic SQL for sp_customer_pattern
    PREPARE stmt FROM @pattern_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Remove the temporary monthly_date column
    ALTER TABLE sw_001_extenso.rw_transaction_data
        DROP COLUMN monthly_date;
END //
DELIMITER ;

CALL sw_001_extenso.sp_customer_pattern('2022-12-01', '2023-05-01');
DROP PROCEDURE sw_001_extenso.sp_customer_pattern;

select * from sw_001_extenso.sp_customer_pattern;
