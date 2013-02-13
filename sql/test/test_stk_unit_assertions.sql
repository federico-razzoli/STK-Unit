/*
    SQLToolKit/Unit
	Copyright Federico Razzoli 2012
	
	This file is part of SQLToolKit/Unit.
	
    SQLToolKit/Unit is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, version 3 of the License.
	
    SQLToolKit/Unit is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
	
    You should have received a copy of the GNU Affero General Public License
    along with SQLToolKit/Unit.  If not, see <http://www.gnu.org/licenses/>.
*/


DELIMITER ||


-- create & select db
CREATE DATABASE IF NOT EXISTS `test_stk_unit_assertions`;
USE `test_stk_unit_assertions`;



/*
 *	Insert Test Data
 *	================
 */


DROP TABLE IF EXISTS `my_tab`;
CREATE TABLE `my_tab` (
	`a`  TINYINT NULL,
	`b`  CHAR(1) NULL
)
	ENGINE   = 'MEMORY',
	DEFAULT CHARACTER SET = ascii,
	COLLATE = ascii_bin,
	COMMENT = 'Test data';

INSERT INTO `my_tab` (`a`, `b`) VALUES (1, '');
INSERT INTO `my_tab` (`a`, `b`) VALUES (2, NULL);

DROP TABLE IF EXISTS `empty_tab`;
CREATE TABLE `empty_tab` (
	`a`  TINYINT NULL,
	`b`  CHAR(1) NULL
)
	ENGINE   = 'MEMORY',
	DEFAULT CHARACTER SET = ascii,
	COLLATE = ascii_bin,
	COMMENT = 'Test data';

DROP TABLE IF EXISTS `ya_tab`;
CREATE TABLE `ya_tab` (
	`a`  TINYINT NULL
)
	ENGINE   = 'MEMORY',
	COMMENT  = 'Test data';

INSERT INTO `ya_tab` (`a`) VALUES (10);
INSERT INTO `ya_tab` (`a`) VALUES (20);
INSERT INTO `ya_tab` (`a`) VALUES (30);

CREATE OR REPLACE VIEW `my_view` AS
	SELECT * FROM `my_tab`;

DROP TRIGGER IF EXISTS `my_trig`;
CREATE TRIGGER `my_trig`
	BEFORE INSERT
	ON `my_tab`
	FOR EACH ROW
BEGIN
	SET @val = NULL;
END;

DROP PROCEDURE IF EXISTS `my_proc`;
CREATE PROCEDURE `my_proc`()
	COMMENT 'Test data'
BEGIN
	SET @val = NULL;
END;

DROP FUNCTION IF EXISTS `my_func`;
CREATE FUNCTION `my_func`()
	RETURNS TINYINT
	DETERMINISTIC
	NO SQL
	COMMENT 'Test data'
BEGIN
	RETURN 1;
END;

DROP EVENT IF EXISTS `my_event`;
CREATE EVENT `my_event`
	ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL 10 YEAR
	ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Test data'
	DO SET @val = NULL;



/*
 *	Insert Tests
 *	============
 */

DROP PROCEDURE IF EXISTS `test_assert`;
CREATE PROCEDURE test_assert()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert() works'
BEGIN
	CALL `stk_unit`.assert(TRUE, 'ERR: This should pass!!');
	CALL `stk_unit`.assert('1', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_ignore_all_exceptions`;
CREATE PROCEDURE test_ignore_all_exceptions()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.ignore_all_exceptions() works'
BEGIN
	CALL `stk_unit`.ignore_all_exceptions();
	CALL `stk_unit`.assert_true(TRUE, 'ERR: This should pass!!');
	CREATE DATABASE `mysql`;
	CALL `stk_unit`.assert_true(FALSE, 'ERR: This should not be tested!!');
END;

DROP PROCEDURE IF EXISTS `test_expect_any_exception`;
CREATE PROCEDURE test_expect_any_exception()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.expect_any_exception() works'
BEGIN
	CALL `stk_unit`.expect_any_exception();
	CALL `stk_unit`.assert_true(TRUE, 'ERR: This should pass!!');
	CREATE DATABASE `mysql`;
	CALL `stk_unit`.assert_true(FALSE, 'ERR: This should not be tested!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_true`;
CREATE PROCEDURE test_assert_true()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_true() works'
BEGIN
	CALL `stk_unit`.assert_true(TRUE, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_true('1', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_false`;
CREATE PROCEDURE test_assert_false()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.test_assert_false() works'
BEGIN
	CALL `stk_unit`.assert_false(FALSE, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_false('0', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_false('', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_null`;
CREATE PROCEDURE test_assert_null()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_null() works'
BEGIN
	CALL `stk_unit`.assert_null(NULL, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_null`;
CREATE PROCEDURE test_assert_not_null()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_null() works'
BEGIN
	CALL `stk_unit`.assert_not_null('', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_equals`;
CREATE PROCEDURE test_assert_equals()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_equals() works'
BEGIN
	CALL `stk_unit`.assert_equals('abc', 'abc', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_equals(1, 1, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_equals('123', 123, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_equals`;
CREATE PROCEDURE test_assert_not_equals()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_equals() works'
BEGIN
	CALL `stk_unit`.assert_not_equals('a', 'b', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_not_equals(1, -1, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_equals`;
CREATE PROCEDURE test_assert_not_equals()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_equals() works'
BEGIN
	CALL `stk_unit`.assert_not_equals('a', 'b', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_not_equals(1, -1, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_like`;
CREATE PROCEDURE test_assert_like()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_like() works'
BEGIN
	CALL `stk_unit`.assert_like('emiliano zapata', 'emiliano%', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_like('carlos santana', '%sa_tana', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_like`;
CREATE PROCEDURE test_assert_not_like()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_like() works'
BEGIN
	CALL `stk_unit`.assert_not_like('carlos santana', '%hey%', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_like_with_escape`;
CREATE PROCEDURE test_assert_like_with_escape()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_like_with_escape() works'
BEGIN
	CALL `stk_unit`.assert_like_with_escape('Erik_', 'Erik|_', '|', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_like_with_escape`;
CREATE PROCEDURE test_assert_not_like_with_escape()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_like_with_escape() works'
BEGIN
	CALL `stk_unit`.assert_not_like_with_escape('Erik!', 'Erik|_', '|', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_regexp`;
CREATE PROCEDURE test_assert_regexp()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_regexp('MariaDB', 'DB', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_regexp`;
CREATE PROCEDURE test_assert_not_regexp()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_not_regexp('MariaDB', 'oracle', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_regexp_binary`;
CREATE PROCEDURE test_assert_regexp_binary()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_regexp_binary('MariaDB', 'DB', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_not_regexp_binary`;
CREATE PROCEDURE test_assert_not_regexp_binary()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_not_regexp_binary('MariaDB', 'db', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_table_exists`;
CREATE PROCEDURE test_assert_table_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_exists() works'
BEGIN
	CALL `stk_unit`.assert_table_exists('test_stk_unit_assertions', 'my_tab', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_table_not_exists`;
CREATE PROCEDURE test_assert_table_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_table_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_table_not_exists('not_exists', 'my_table', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_view_exists`;
CREATE PROCEDURE test_assert_view_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_view_exists() works'
BEGIN
	CALL `stk_unit`.assert_view_exists('test_stk_unit_assertions', 'my_view', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_view_not_exists`;
CREATE PROCEDURE test_assert_view_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_view_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_view_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_view_not_exists('not_exists', 'my_view', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_routine_exists`;
CREATE PROCEDURE test_assert_routine_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_routine_exists() works'
BEGIN
	CALL `stk_unit`.assert_routine_exists('test_stk_unit_assertions', 'my_func', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_routine_exists('test_stk_unit_assertions', 'my_proc', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_routine_not_exists`;
CREATE PROCEDURE test_assert_routine_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_routine_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_routine_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_routine_not_exists('not_exists', 'my_proc', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_event_exists`;
CREATE PROCEDURE test_assert_event_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_event_exists() works'
BEGIN
	CALL `stk_unit`.assert_event_exists('test_stk_unit_assertions', 'my_event', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_event_not_exists`;
CREATE PROCEDURE test_assert_event_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_event_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_event_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_event_not_exists('not_exists', 'my_event', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_trigger_exists`;
CREATE PROCEDURE test_assert_trigger_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_trigger_exists() works'
BEGIN
	CALL `stk_unit`.assert_trigger_exists('test_stk_unit_assertions', 'my_trig', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_trigger_not_exists`;
CREATE PROCEDURE test_assert_trigger_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_trigger_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_trigger_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_trigger_not_exists('not_exists', 'my_trig', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_column_exists`;
CREATE PROCEDURE test_assert_column_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_column_exists() works'
BEGIN
	CALL `stk_unit`.assert_column_exists('test_stk_unit_assertions', 'my_tab', 'a', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_column_not_exists`;
CREATE PROCEDURE test_assert_column_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_column_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_column_not_exists('not_exists', 'my_tab', 'a', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_column_not_exists('test_stk_unit_assertions', 'not_exists', 'a', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_column_not_exists('test_stk_unit_assertions', 'my_tab', 'not_exists', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_row_exists`;
CREATE PROCEDURE test_assert_row_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_row_exists() works'
BEGIN
	CALL `stk_unit`.assert_row_exists('test_stk_unit_assertions', 'my_tab', 'a', 1, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_row_exists('test_stk_unit_assertions', 'my_tab', 'b', NULL, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_row_not_exists`;
CREATE PROCEDURE test_assert_row_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_row_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_row_not_exists('test_stk_unit_assertions', 'my_tab', 'a', 100, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_row_not_exists('test_stk_unit_assertions', 'my_tab', 'a', NULL, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_rows_count`;
CREATE PROCEDURE test_assert_rows_count()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_rows_count() works'
BEGIN
	CALL `stk_unit`.assert_rows_count('test_stk_unit_assertions', 'my_tab', 2, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_table_empty`;
CREATE PROCEDURE test_assert_table_empty()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_empty() works'
BEGIN
	CALL `stk_unit`.assert_table_empty('test_stk_unit_assertions', 'empty_tab', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_table_not_empty`;
CREATE PROCEDURE test_assert_table_not_empty()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_not_empty() works'
BEGIN
	CALL `stk_unit`.assert_table_not_empty('test_stk_unit_assertions', 'my_tab', 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_field_count_distinct`;
CREATE PROCEDURE test_assert_field_count_distinct()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_count_distinct() works'
BEGIN
	CALL `stk_unit`.assert_field_count_distinct('test_stk_unit_assertions', 'my_tab', 'a', 2, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_field_count_distinct('test_stk_unit_assertions', 'my_tab', 'b', 1, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_field_min`;
CREATE PROCEDURE test_assert_field_min()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_min() works'
BEGIN
	CALL `stk_unit`.assert_field_min('test_stk_unit_assertions', 'ya_tab', 'a', 10, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_field_avg`;
CREATE PROCEDURE test_assert_field_avg()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_avg() works'
BEGIN
	CALL `stk_unit`.assert_field_avg('test_stk_unit_assertions', 'ya_tab', 'a', 20, 'ERR: This should pass!!');
END;

DROP PROCEDURE IF EXISTS `test_assert_field_max`;
CREATE PROCEDURE test_assert_field_max()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_max() works'
BEGIN
	CALL `stk_unit`.assert_field_max('test_stk_unit_assertions', 'ya_tab', 'a', 30, 'ERR: This should pass!!');
END;

||

DELIMITER ;
