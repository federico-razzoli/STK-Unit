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

##begin


-- here go test suites
CREATE DATABASE IF NOT EXISTS `stk_suite`;

-- create & select main db
CREATE DATABASE IF NOT EXISTS `stk_unit`;
USE `stk_unit`;



-- tables


DROP TABLE IF EXISTS `dbug_log`;
DROP TABLE IF EXISTS `config`;
DROP TABLE IF EXISTS `test_results`;
DROP TABLE IF EXISTS `test_run`;


-- here one can insert debug messages
CREATE TABLE `dbug_log` (
	`id`          MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`timestamp`   TIMESTAMP/*!50300(6)*/ NOT NULL DEFAULT CURRENT_TIMESTAMP   COMMENT 'Entry timestamp',
	`connection`  BIGINT UNSIGNED                                             COMMENT 'Thread that logged this',
	`msg`         CHAR(255) NOT NULL DEFAULT ''                               COMMENT 'Debug message'
)
	ENGINE   = 'Aria',
	COMMENT = 'Can be used to log debug messages';

-- Configuration options.
-- If test_case IS NULL they're global, else they're associated to a TC.
-- TC-level options overwrite global ones, when their TC runs.
-- All options can be TC-level, even if it may not make sense.
-- Invalid options are not written here.
CREATE TABLE `config` (
	`var_key`    CHAR(10)  NOT NULL DEFAULT ''    COMMENT 'Name of the conf var',
	`var_val`    CHAR(50)  NOT NULL DEFAULT ''    COMMENT 'Current value',
	`test_case`  CHAR(64)  NOT NULL DEFAULT ''    COMMENT 'TC the value applies to; empty=global',
	UNIQUE INDEX `uni_key` (`var_key`, `test_case`)
)
	ENGINE   = 'Aria',
	DEFAULT CHARACTER SET = ascii,
	COLLATE = ascii_bin,
	COMMENT  = 'Config variables: global & tc-level';

-- default options
TRUNCATE TABLE `config`;
INSERT INTO `config` (`var_key`, `var_val`, `test_case`) VALUES ('dbug', '0', DEFAULT);
INSERT INTO `config` (`var_key`, `var_val`, `test_case`) VALUES ('show_err', '0', DEFAULT);
INSERT INTO `config` (`var_key`, `var_val`, `test_case`) VALUES ('out_format', 'text', DEFAULT);

-- test execution data
CREATE TABLE `test_run` (
	`id`          MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`timestamp`   TIMESTAMP/*!50300(6)*/ NOT NULL DEFAULT CURRENT_TIMESTAMP   COMMENT 'Run start timestamp',
	`run_by`      BIGINT UNSIGNED NOT NULL DEFAULT 0                          COMMENT 'Id of connection that run test',
	`test_suite`  CHAR(64) NOT NULL DEFAULT ''                                COMMENT 'Name of most external TS',
	`test_case`   CHAR(64) NOT NULL DEFAULT ''                                COMMENT 'TC name, if not a TS'
)
	ENGINE   = 'InnoDB',
	COMMENT = 'Test cases/suites runs';

-- results of single tests (not cases or suites)
CREATE TABLE `test_results` (
	`id`          MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`timestamp`   TIMESTAMP/*!50300(6)*/ NOT NULL DEFAULT  CURRENT_TIMESTAMP,
	`run_by`      BIGINT UNSIGNED NOT NULL DEFAULT 0       COMMENT 'Connectio that run test',
	`test_run`    MEDIUMINT UNSIGNED NOT NULL DEFAULT 0    COMMENT 'FK to test_run',
	`test_case`   CHAR(64) NOT NULL DEFAULT ''             COMMENT 'Database',
	`test_name`   CHAR(64) NOT NULL DEFAULT ''             COMMENT 'Procedure name',
	`assert_num`  MEDIUMINT UNSIGNED NOT NULL DEFAULT 0    COMMENT 'Test-level assert prog number',
	`results`     ENUM('fail', 'pass', 'exception') NOT NULL DEFAULT 'fail' COMMENT 'pass = ok, fail = assert failed, exception = unexpected error',
	`msg`         CHAR(255) NOT NULL DEFAULT ''            COMMENT 'Fail/error message',
	CONSTRAINT `fk_test_results_test_run` FOREIGN KEY `fk_test_run` (`test_run`) REFERENCES `test_run` (`id`)
		ON DELETE CASCADE
)
	ENGINE   = 'InnoDB',
	COMMENT  = 'Results of individual tests';


-- test_results with only most recent runs
CREATE OR REPLACE VIEW `last_test_results` AS
	SELECT *
		FROM `test_results`
		WHERE `test_run` = (SELECT MAX(`id`) FROM `test_run`)
		ORDER BY `id` ASC;

-- last_test_results with only failed + exceptions
CREATE OR REPLACE VIEW `last_test_results_bad` AS
	SELECT *
		FROM `last_test_results`
		WHERE `results` <> 'pass'
		ORDER BY `id` ASC;

-- test_results of each test's last run
CREATE OR REPLACE VIEW `recent_test_results` AS
	SELECT *
		FROM `test_results`
		WHERE `test_run` IN (SELECT MAX(`test_run`) FROM `test_results` GROUP BY `test_case`)
		ORDER BY `test_run` DESC, `id` ASC;

-- recent_test_results with only failed + exceptions
CREATE OR REPLACE VIEW `recent_test_results_bad` AS
	SELECT *
		FROM `recent_test_results`
		WHERE `results` <> 'pass'
		ORDER BY `id` ASC;

-- summary with only most recent test run
CREATE OR REPLACE VIEW `last_test_summary` AS
	SELECT
		(SELECT COUNT(*) FROM `last_test_results`) AS `total`,
		(SELECT COUNT(*) FROM `last_test_results` WHERE `results` = 'pass') AS `passed`,
		(SELECT COUNT(*) FROM `last_test_results` WHERE `results` = 'fail') AS `failed`,
		(SELECT COUNT(*) FROM `last_test_results` WHERE `results` = 'exception') AS `exceptions`;

-- summary of each test's last run (in a relational form)
CREATE OR REPLACE VIEW `recent_test_summary_relational` AS
	SELECT
			`test_case`, `test_run`, `results`, COUNT(*) AS `number`
		FROM `recent_test_results`
		GROUP BY `test_run`, `results`;

-- summary of each test's last run (in a readable form)
CREATE OR REPLACE VIEW `recent_test_summary` AS
	SELECT
			`test_case`, `test_run`,
			IF( (SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'pass'),
				(SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'pass'),
				0) AS `pass`,
			IF( (SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'fail'),
				(SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'fail'),
				0) AS `fail`,
			IF( (SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'exception'),
				(SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'exception'),
				0) AS `exception`,
			(SELECT SUM(`number`) FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run`)
				AS `total`
		FROM `recent_test_summary_relational` r_read
		GROUP BY `test_case`
		ORDER BY `test_run` DESC;

-- test case names (databases starting with 'test_')
CREATE OR REPLACE VIEW `TEST_CASE` AS
	SELECT `SCHEMA_NAME` AS `TEST_NAME`
		FROM `information_schema`.`SCHEMATA`
		WHERE `SCHEMA_NAME` LIKE BINARY 'test\_%'
		ORDER BY `SCHEMA_NAME` ASC;

-- test case names (databases starting with 'test_')
CREATE OR REPLACE VIEW `TEST_SUITE` AS
	SELECT `ROUTINE_NAME` AS `SUITE_NAME`
		FROM `information_schema`.`ROUTINES`
		WHERE `ROUTINE_SCHEMA` = 'test_suite'
		ORDER BY `ROUTINE_SCHEMA` ASC;

-- summary of each test's last run (in a relational form)
CREATE OR REPLACE VIEW `my_dbug_log` AS
	SELECT
			`timestamp`, `msg`
		FROM `dbug_log`
		WHERE `connection` = (SELECT `connection` FROM `dbug_log` ORDER BY `timestamp` DESC LIMIT 1)
		ORDER BY `timestamp` ASC;



-- stored routines


-- returns wether specified Stored Procedure exists
DROP FUNCTION IF EXISTS `procedure_exists`;
CREATE FUNCTION procedure_exists(sp_schema CHAR(64), sp_name CHAR(64))
	RETURNS BOOL
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Returns wether specified Stored Procedure exists'
BEGIN
	RETURN EXISTS (
		SELECT `ROUTINE_NAME`
			FROM `information_schema`.`ROUTINES`
			WHERE      `ROUTINE_SCHEMA`  = `sp_schema`
				  AND  `ROUTINE_NAME`    = `sp_name`
				  AND  `ROUTINE_TYPE`    = 'PROCEDURE'
		);
END;

-- calls `sp_schema`.`sp_name`()
DROP PROCEDURE IF EXISTS `procedure_call`;
CREATE PROCEDURE procedure_call(IN sp_schema CHAR(64), IN sp_name CHAR(64))
	LANGUAGE SQL
	COMMENT 'Calls `sp_schema`.`sp_name`()'
BEGIN
	SET @__stk_call_tc = CONCAT('CALL `', sp_schema, '`.`', sp_name, '`();');
	
	PREPARE __stk_u_stmt_call FROM @__stk_call_tc;
	SET @__stk_call_tc = NULL;
	EXECUTE __stk_u_stmt_call;
	DEALLOCATE PREPARE __stk_u_stmt_call;
END;

-- set a configuration option:
-- global if no test is running in the current session,
-- tc-level if a tc is running (running_test temptable)
DROP PROCEDURE IF EXISTS `config_set`;
CREATE PROCEDURE config_set(
		opt_key CHAR(64) CHARACTER SET 'ascii' /*M!55000 COLLATE 'ascii_bin' */,
		opt_val CHAR(10) CHARACTER SET 'ascii' /*M!55000 COLLATE 'ascii_bin' */
		)
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Set a configuration option'
main_block:
BEGIN
	-- valid option?
	IF (NOT opt_key IN('show_err', 'dbug')) THEN
		-- return error or exit procedure
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit] Invalid Configuration Option';
		*/
		LEAVE main_block;
	END IF;
	
	REPLACE
		INTO      `stk_unit`.`config`
		SET       `var_key`  = opt_key,
		          `var_val`  = opt_val,
				  `test_case` = IFNULL(@__stk_test_case, '');
END main_block ;

-- gets configuration option value:
-- tc-level if a tc is running, else global
DROP FUNCTION IF EXISTS `config_get`;
CREATE FUNCTION config_get(`opt_key` CHAR(64) CHARACTER SET 'ascii' /*M!55000 COLLATE 'ascii_bin' */)
	RETURNS CHAR(10)
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Return a configuration option'
BEGIN
	-- option value goes here
	DECLARE `tc` CHAR(64) DEFAULT IFNULL(@__stk_test_case, '');
	
	-- if opt_key is not there, return NULL
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		RETURN NULL;
	
	RETURN (
			SELECT `var_val`
				FROM `stk_unit`.`config`
				WHERE `var_key` = `opt_key`
				ORDER BY `test_case` <> `tc`
				LIMIT 1
		);
END;

-- write a debug message in the dbug_log table
DROP PROCEDURE IF EXISTS `dbug_log`;
CREATE PROCEDURE dbug_log(IN msg CHAR(255))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Write a debug message in the dbug_log table'
BEGIN
	INSERT INTO dbug_log (`msg`, `connection`) VALUES (msg, CONNECTION_ID());
END;

-- add an entry to test_results
DROP PROCEDURE IF EXISTS `log_result`;
CREATE PROCEDURE log_result(IN res CHAR(9), IN msg CHAR(255))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Add an entry to test_results'
BEGIN
	-- log status info & error
	INSERT INTO `stk_unit`.`test_results`
			(`test_run`, `run_by`, `test_name`, `test_case`, `assert_num`, `results`, `msg`)
		VALUES
			(@__stk_run_id, CONNECTION_ID(), @__stk_test_name, @__stk_test_case, @__stk_assert_num + 1, res, msg);
END;

-- empty expect table
DROP PROCEDURE IF EXISTS `clean_expect`;
CREATE PROCEDURE clean_expect()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Deletes all expectations'
BEGIN
	TRUNCATE TABLE `stk_unit`.`expect`;
END;

-- Check if last run Test Case had an unsitified expected exception.
-- If it had, records the error in test_results.
DROP PROCEDURE IF EXISTS `check_expect`;
CREATE PROCEDURE check_expect()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Check if last run Test Case had an unsitified expected exception'
BEGIN
	IF (SELECT COUNT(*) > 0 FROM `stk_unit`.`expect` WHERE `action` = 'expect') THEN
		CALL `stk_unit`.log_result('fail', 'Expected Exception');
		
		-- delete expectation
		CALL `stk_unit`.clean_expect();
	END IF;
END;

-- handles any kind of exceptions
DROP PROCEDURE IF EXISTS `handle_exception`;
CREATE PROCEDURE handle_exception()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Handle errors. RESIGNAL mu errors, log user errors.'
BEGIN
	IF @__stk_throw_error = TRUE THEN
		-- framework error. re-throw
		/*!50500
			RESIGNAL;
		*/
		DO NULL;
	ELSEIF (SELECT COUNT(*) > 0 FROM `stk_unit`.`expect`) THEN
		-- trigger a pass
		CALL `stk_unit`.log_result('pass', 'Satisfied Excpectation');
		-- expected/ignored exception
		CALL `stk_unit`.clean_expect();
	ELSE
		-- uncatched exception.
		-- if 'show_err' option is set, RESIGNAL (if possible);
		-- else, gracefully record an uncatched exception
		IF `stk_unit`.config_get('show_err') <> '0' THEN
			-- framework error. re-throw
			/*!50500
				RESIGNAL;
			*/
			DO NULL;
		END IF;
		CALL `stk_unit`.log_result('exception', 'Uncatched Exception');
	END IF;
END;

-- drop temptables
DROP PROCEDURE IF EXISTS `deinit_status`;
CREATE PROCEDURE deinit_status()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Drop temptables used for test status'
BEGIN
	-- clean temptables
	DROP TEMPORARY TABLE IF EXISTS `stk_unit`.`expect`;
	
	-- if later in this session a TC is called,
	-- it must know that it is not part of a TS.
	SET @__stk_ts = NULL;
	
	-- if a TS is called later in this session,
	-- it must know that no TC is in progress
	SET @__stk_test_case = NULL;
	
	-- clean all variables, just to be safe
	SET @__stk_run_id       = NULL;
	SET @__stk_test_name    = NULL;
	SET @__stk_assert_num   = NULL;
	SET @__stk_u_res        = NULL;
END;

-- create and fill vars table
DROP PROCEDURE IF EXISTS `init_status`;
CREATE PROCEDURE init_status()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Create and fill temp tables'
BEGIN
	-- exceptions ignored/expected
	DROP TEMPORARY TABLE IF EXISTS `stk_unit`.`expect`;
	CREATE TEMPORARY TABLE `stk_unit`.`expect` (
		`action`      ENUM('ignore', 'expect') NOT NULL      COMMENT 'ignore = no effect; expect = must happen',
		`errno`       SMALLINT UNSIGNED NULL DEFAULT NULL    COMMENT 'Exception code'
	)
		ENGINE   = 'MEMORY',
		DEFAULT CHARACTER SET = ascii,
		COLLATE = ascii_bin,
		COMMENT  = 'Exceptions to be ignored/expected';
	
	-- write and read run_id
	INSERT INTO `stk_unit`.`test_run`
			(`run_by`, `test_suite`, `test_case`)
		VALUES
			(CONNECTION_ID(), IFNULL(@__stk_ts, ''), IFNULL(@__stk_test_case, ''));
	SET @__stk_run_id = (SELECT LAST_INSERT_ID());
	
	-- init other vars
	SET @__stk_test_name    = NULL;
	SET @__stk_assert_num   = NULL;
	SET @__stk_u_res        = NULL;
END;

-- execute a test case
DROP PROCEDURE IF EXISTS `test_case_run`;
CREATE PROCEDURE test_case_run(IN tc CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Run a Test Case'
BEGIN
	-- bt name
	DECLARE test_name     CHAR(64) DEFAULT NULL;
	-- end-of-data handler
	DECLARE eof           BOOL DEFAULT FALSE;
	-- number of tests found
	DECLARE num_tests     MEDIUMINT UNSIGNED DEFAULT 0;
	-- existing user functions
	DECLARE exists_set_up     BOOL DEFAULT FALSE;
	DECLARE exists_tear_down  BOOL DEFAULT FALSE;
	
	
	-- query to get tests from tc
	DECLARE cur_tables CURSOR FOR
		SELECT r.`SPECIFIC_NAME`
			FROM `information_schema`.`ROUTINES` r
			/*!50500 LEFT JOIN `information_schema`.`PARAMETERS` p
			ON r.`SPECIFIC_NAME` = p.`SPECIFIC_NAME` */
			WHERE r.`ROUTINE_SCHEMA` = tc AND r.`ROUTINE_TYPE` = 'PROCEDURE' AND r.`SPECIFIC_NAME` LIKE 'test\_%'
				/*!50500 AND p.`PARAMETER_NAME` IS NULL */ ;
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET eof = TRUE;
	
	DECLARE CONTINUE HANDLER
		FOR SQLWARNING, SQLEXCEPTION
		CALL `stk_unit`.handle_exception();
	
	
	SET @__stk_throw_error = TRUE;
	
	-- need to remember current test case
	-- even if we're in a TS
	SET @__stk_test_case = tc;
	
	-- log tc name
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Starting TC: `', IFNULL(tc, ''), '`'));
	END IF;
	
	-- create temptables
	-- (if we're not inside a TS)
	IF @__stk_ts IS NULL THEN
		CALL `stk_unit`.init_status();
	END IF;
	
	-- prepare all tests
	IF procedure_exists(tc, 'before_all_tests') = TRUE THEN
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`before_all_tests`'));
		END IF;
		CALL procedure_call(tc, 'before_all_tests');
	END IF;
	
	-- do set_up() and tear_down() exist?
	SET exists_set_up     = procedure_exists(tc, 'set_up');
	SET exists_tear_down  = procedure_exists(tc, 'tear_down');
	
	-- get tests
	OPEN cur_tables;
	do_test: LOOP
		FETCH cur_tables INTO test_name;
		
		-- must be accessible from log_result()
		SET @__stk_test_name = test_name;
		
		-- end of test case?
		IF eof = TRUE THEN
			LEAVE do_test;
		END IF;
		SET num_tests = num_tests + 1;
		
		-- log test name
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Found BT: `', IFNULL(test_name, ''), '`'));
		END IF;
		
		-- reset unit test runs
		SET @__stk_assert_num = 0;
		-- test errors must not be RESIGNALed
		SET @__stk_throw_error = FALSE;
		
		-- run set_up()
		IF exists_set_up = TRUE THEN
			IF config_get('dbug') = '1' THEN
				CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`set_up`'));
			END IF;
			CALL procedure_call(tc, 'set_up');
		END IF;
		
		-- run next test
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling BT: `', IFNULL(tc, ''), '`.`', IFNULL(test_name, ''), '`'));
		END IF;
		CALL procedure_call(tc, test_name);
		
		-- last test has an unsitisfied expected exception?
		CALL `stk_unit`.check_expect();
		
		-- run tear_down()
		IF exists_tear_down = TRUE THEN
			IF config_get('dbug') = '1' THEN
				CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`tear_down`'));
			END IF;
			CALL procedure_call(tc, 'tear_down');
		END IF;
	END LOOP;
	CLOSE cur_tables;
	
	-- log tc name
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Ending TC: `', IFNULL(tc, ''), '`'));
	END IF;
	
	-- clean after all tests
	IF procedure_exists(tc, 'after_all_tests') = TRUE THEN
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`after_all_tests`'));
		END IF;
		CALL procedure_call(tc, 'after_all_tests');
	END IF;
	
	-- but if we're executing a TS, individual TC's
	-- must not create/drop status temptable
	IF @__stk_ts IS NULL THEN
		CALL `stk_unit`.deinit_status();
	END IF;
	
	-- no tests? error
	IF num_tests = 0 THEN
		-- SIGNAL a tests not found,
		-- that will be RESIGNALed
		SET @__stk_throw_error = TRUE;
		
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_case_run] No tests found';
		*/
	END IF;
END;

-- execute a test case
DROP PROCEDURE IF EXISTS `test_suite_run`;
CREATE PROCEDURE test_suite_run(IN ts CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Run a Test Suite'
BEGIN
	-- log tc name
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Starting TS: `', IFNULL(ts, ''), '`'));
	END IF;
	
	IF procedure_exists('stk_suite', ts) = TRUE THEN
		-- remember TS name: TC must not init/deinit status
		SET @__stk_ts = ts;
		
		-- status initialized by TS, not individual TC's
		CALL `stk_unit`.init_status();
		
		-- execute TS
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling TS: `', IFNULL(ts, ''), '`'));
		END IF;
		SET @__stk_call = CONCAT('CALL `stk_suite`.`', ts, '`();');
		PREPARE __stk_stmt_call_ts FROM @__stk_call;
		SET @__stk_call = NULL;
		EXECUTE __stk_stmt_call_ts;
		DEALLOCATE PREPARE __stk_stmt_call_ts;
		
		-- log TS end before cleaning
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Ending TS: `', IFNULL(ts, ''), '`'));
		END IF;
		
		-- clean temptables.
		-- for now, TS's cannot be recursive
		CALL `stk_unit`.deinit_status();
	ELSE
		-- clean temptables even if somehint go wrong
		CALL `stk_unit`.deinit_status();
		
		-- TS not found, throw error
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_suite_run] Test Suite not found';
		*/
	END IF;
END;



#
#	Exceptions
#

-- throw an error if there is already an expectation
DROP PROCEDURE IF EXISTS `no_double_expectation`;
CREATE PROCEDURE no_double_expectation()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Raises an error if an expectation is already there'
BEGIN
	-- there was an expectarion already? error!
	IF EXISTS (SELECT 1 FROM `stk_unit`.`expect`) THEN
		-- this error must be RESIGNALed
		SET @__stk_throw_error = TRUE;
		
		-- raise error
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
			MESSAGE_TEXT  = '[STK/Unit] Only one expectation per Base Test is allowed';
			*/
	END IF;
END;

DROP PROCEDURE IF EXISTS `ignore_all_exceptions`;
CREATE PROCEDURE ignore_all_exceptions()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Ignore all exceptions for this unit test'
BEGIN
	-- check that an expectation was not already there
	CALL `stk_unit`.no_double_expectation();
	
	-- insert new expectation
	INSERT INTO `stk_unit`.`expect`
		(`action`, `errno`)
		VALUES
		('ignore', NULL);
END;

DROP PROCEDURE IF EXISTS `expect_any_exception`;
CREATE PROCEDURE expect_any_exception()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Except an exception for this unit test'
BEGIN
	-- check that an expectation was not already there
	CALL `stk_unit`.no_double_expectation();
	
	-- insert new expectation
	INSERT INTO `stk_unit`.`expect`
		(`action`, `errno`)
		VALUES
		('expect', NULL);
END;


#
#	Assertions
#

-- low-level assertion
DROP PROCEDURE IF EXISTS `assert`;
CREATE PROCEDURE assert(IN cond TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Internal. Low-level assertion'
BEGIN
	-- 'fail' or 'pass'
	DECLARE cond_result CHAR(9) DEFAULT NULL;
	
	-- msg must only be stored on fail
	IF cond <> '0' THEN
		SET msg = '';
		SET cond_result = 'pass';
	ELSE
		SET cond_result = 'fail';
	END IF;
	
	-- log status info & assert result
	CALL `stk_unit`.log_result(cond_result, msg);
	
	SET @__stk_assert_num = @__stk_assert_num + 1;
END;



DROP PROCEDURE IF EXISTS `assert_true`;
CREATE PROCEDURE assert_true(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is not FALSE'
BEGIN
	CALL `stk_unit`.assert(val, msg);
END;

DROP PROCEDURE IF EXISTS `assert_false`;
CREATE PROCEDURE assert_false(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is FALSE'
BEGIN
	CALL `stk_unit`.assert(val = FALSE, msg);
END;

DROP PROCEDURE IF EXISTS `assert_null`;
CREATE PROCEDURE assert_null(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is NULL'
BEGIN
	CALL `stk_unit`.assert(val IS NULL, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_null`;
CREATE PROCEDURE assert_not_null(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is NOT NULL'
BEGIN
	CALL `stk_unit`.assert(val IS NOT NULL, msg);
END;

DROP PROCEDURE IF EXISTS `assert_equals`;
CREATE PROCEDURE assert_equals(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed values are equal'
BEGIN
	CALL `stk_unit`.assert(val1 = val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_equals`;
CREATE PROCEDURE assert_not_equals(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed values are different'
BEGIN
	CALL `stk_unit`.assert(val1 <> val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_like`;
CREATE PROCEDURE assert_like(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 LIKE val2'
BEGIN
	CALL `stk_unit`.assert(val1 LIKE val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_like`;
CREATE PROCEDURE assert_not_like(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT LIKE val2'
BEGIN
	CALL `stk_unit`.assert(val1 NOT LIKE val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_like_with_escape`;
CREATE PROCEDURE assert_like_with_escape(IN val1 TEXT, IN val2 TEXT, IN esc_chr CHAR(1), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 LIKE val2 ESCAPE chr'
BEGIN
	CALL `stk_unit`.assert(val1 LIKE val2 ESCAPE esc_chr, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_like_with_escape`;
CREATE PROCEDURE assert_not_like_with_escape(IN val1 TEXT, IN val2 TEXT, IN esc_chr CHAR(1), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT LIKE val2 ESCAPE chr'
BEGIN
	CALL `stk_unit`.assert(val1 NOT LIKE val2 ESCAPE esc_chr, msg);
END;

DROP PROCEDURE IF EXISTS `assert_regexp`;
CREATE PROCEDURE assert_regexp(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 REGEXP val2'
BEGIN
	CALL `stk_unit`.assert(val1 REGEXP val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_regexp`;
CREATE PROCEDURE assert_not_regexp(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT REGEXP val2'
BEGIN
	CALL `stk_unit`.assert(val1 NOT REGEXP val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_regexp_binary`;
CREATE PROCEDURE assert_regexp_binary(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 REGEXP BINARY val2'
BEGIN
	CALL `stk_unit`.assert(val1 REGEXP BINARY val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_regexp_binary`;
CREATE PROCEDURE assert_not_regexp_binary(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT REGEXP BINARY val2'
BEGIN
	CALL `stk_unit`.assert(val1 NOT REGEXP BINARY val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_table_exists`;
CREATE PROCEDURE assert_table_exists(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the database called db contains a table named tab'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) > 0 FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_table_not_exists`;
CREATE PROCEDURE assert_table_not_exists(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the database called db does not contain tab'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) = 0 FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_view_exists`;
CREATE PROCEDURE assert_view_exists(IN db CHAR(64), IN viw CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains view viw'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) > 0 FROM `information_schema`.`VIEWS` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = viw),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_view_not_exists`;
CREATE PROCEDURE assert_view_not_exists(IN db CHAR(64), IN viw CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain view viw'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `TABLE_NAME` FROM `information_schema`.`VIEWS` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = viw),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_routine_exists`;
CREATE PROCEDURE assert_routine_exists(IN db CHAR(64), IN sr_name CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains routine sr_name'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) > 0 FROM `information_schema`.`ROUTINES` WHERE `ROUTINE_SCHEMA` = db AND `SPECIFIC_NAME` = sr_name),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_routine_not_exists`;
CREATE PROCEDURE assert_routine_not_exists(IN db CHAR(64), IN sr_name CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain routine sr_name'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) = 0 FROM `information_schema`.`ROUTINES` WHERE `ROUTINE_SCHEMA` = db AND `SPECIFIC_NAME` = sr_name),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_event_exists`;
CREATE PROCEDURE assert_event_exists(IN db CHAR(64), IN ev CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains event ev'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) > 0 FROM `information_schema`.`EVENTS` WHERE `EVENT_SCHEMA` = db AND `EVENT_NAME` = ev),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_event_not_exists`;
CREATE PROCEDURE assert_event_not_exists(IN db CHAR(64), IN ev CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain event ev'
BEGIN
	CALL `stk_unit`.assert(
			(SELECT COUNT(*) = 0 FROM `information_schema`.`EVENTS` WHERE `EVENT_SCHEMA` = db AND `EVENT_NAME` = ev),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_trigger_exists`;
CREATE PROCEDURE assert_trigger_exists(IN db CHAR(64), IN trig CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains trigger trig'
BEGIN
	CALL `stk_unit`.assert(
			EXISTS (SELECT `TRIGGER_NAME` FROM `information_schema`.`TRIGGERS` WHERE `TRIGGER_SCHEMA` = db AND `TRIGGER_NAME` = trig),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_trigger_not_exists`;
CREATE PROCEDURE assert_trigger_not_exists(IN db CHAR(64), IN trig CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain trigger trig'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `TRIGGER_NAME` FROM `information_schema`.`TRIGGERS` WHERE `TRIGGER_SCHEMA` = db AND `TRIGGER_NAME` = trig),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_column_exists`;
CREATE PROCEDURE assert_column_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db contains column col'
BEGIN
	CALL `stk_unit`.assert(
		EXISTS (SELECT 1 FROM `information_schema`.`COLUMNS`
			WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab AND `COLUMN_NAME` = col),
		msg);
END;

DROP PROCEDURE IF EXISTS `assert_column_not_exists`;
CREATE PROCEDURE assert_column_not_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db does not contain column col'
BEGIN
	CALL `stk_unit`.assert(
		NOT EXISTS (SELECT 1 FROM `information_schema`.`COLUMNS`
			WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab AND `COLUMN_NAME` = col),
		msg);
END;

DROP PROCEDURE IF EXISTS `assert_row_exists`;
CREATE PROCEDURE assert_row_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db contains the specified col=val'
BEGIN
	-- @__stk_u_cmd_assert_row_exists will look like this:
	/*
			SELECT 'assert_temp' AS var_key EXISTS (
				SELECT 1
					FROM `db`.`tab`
					WHERE `col` = 'val'
					or:
					WHERE `col` IS NULL
			) INTO @__stk_u_res;
	*/
	
	-- compose query
	SET @__stk_u_cmd_assert_row_exists = CONCAT(
			'SELECT EXISTS (',
			'SELECT 1 FROM `', db, '`.`', tab, '` '
		);
	IF val IS NULL THEN
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` IS NULL');
	ELSE
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` = ''', val, '''');
	END IF;
	SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
		') INTO @__stk_u_res;');
	
	-- run query
	PREPARE __stk_u_stmt_assert_row_exists FROM @__stk_u_cmd_assert_row_exists;
	EXECUTE __stk_u_stmt_assert_row_exists;
	SET @__stk_u_cmd_assert_row_exists = NULL;
	DEALLOCATE PREPARE __stk_u_stmt_assert_row_exists;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_row_not_exists`;
CREATE PROCEDURE assert_row_not_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that tab in db does not contain the specified col=val'
BEGIN
	-- @__stk_u_cmd_assert_row_exists will look like this:
	/*
			SELECT 'assert_temp' AS var_key NOT EXISTS (
				SELECT 1
					FROM `db`.`tab`
					WHERE `col` = 'val'
					or:
					WHERE `col` IS NULL
			) INTO @__stk_u_res;
	*/
	
	-- compose query
	SET @__stk_u_cmd_assert_row_exists = CONCAT(
			'SELECT NOT EXISTS (',
			'SELECT 1 FROM `', db, '`.`', tab, '` '
		);
	IF val IS NULL THEN
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` IS NULL');
	ELSE
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` = ''', val, '''');
	END IF;
	SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
		') INTO @__stk_u_res;');
	
	-- run query
	PREPARE __stk_u_stmt_assert_row_exists FROM @__stk_u_cmd_assert_row_exists;
	SET @__stk_u_cmd_assert_row_exists = NULL;
	EXECUTE __stk_u_stmt_assert_row_exists;
	DEALLOCATE PREPARE __stk_u_stmt_assert_row_exists;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_rows_count`;
CREATE PROCEDURE assert_rows_count(IN db CHAR(64), IN tab CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db contains num rows'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_rows_count = CONCAT(
			'SELECT COUNT(*) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_rows_count FROM @__stk_u_cmd_assert_rows_count;
	SET @__stk_u_cmd_assert_rows_count = NULL;
	EXECUTE __stk_u_stmt_assert_rows_count;
	DEALLOCATE PREPARE __stk_u_stmt_assert_rows_count;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_table_empty`;
CREATE PROCEDURE assert_table_empty(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db is empty'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_rows_count = CONCAT(
			'SELECT COUNT(*) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_rows_count FROM @__stk_u_cmd_assert_rows_count;
	SET @__stk_u_cmd_assert_rows_count = NULL;
	EXECUTE __stk_u_stmt_assert_rows_count;
	DEALLOCATE PREPARE __stk_u_stmt_assert_rows_count;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = 0, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_table_not_empty`;
CREATE PROCEDURE assert_table_not_empty(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db is not empty'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_rows_count = CONCAT(
			'SELECT COUNT(*) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_rows_count FROM @__stk_u_cmd_assert_rows_count;
	SET @__stk_u_cmd_assert_rows_count = NULL;
	EXECUTE __stk_u_stmt_assert_rows_count;
	DEALLOCATE PREPARE __stk_u_stmt_assert_rows_count;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res <> 0, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_count_distinct`;
CREATE PROCEDURE assert_field_count_distinct(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that db.tab.col contains num unique values'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT COUNT(DISTINCT `', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_min`;
CREATE PROCEDURE assert_field_min(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that MIN(db.tab.col) = num'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT MIN(`', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_max`;
CREATE PROCEDURE assert_field_max(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that MAX(db.tab.col) = num'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT MAX(`', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_avg`;
CREATE PROCEDURE assert_field_avg(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that AVG(db.tab.col) = num'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT AVG(`', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;


##end

||
DELIMITER ;
