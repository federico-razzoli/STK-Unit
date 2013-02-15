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


DROP PROCEDURE IF EXISTS `stk_suite`.`stk_unit`;
CREATE PROCEDURE `stk_suite`.stk_unit()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'All TCs for STKUnit'
BEGIN
	CALL `stk_unit`.`test_case_run`('test_stk_unit');
	CALL `stk_unit`.`test_case_run`('test_stk_unit_assertions');
END;


||
DELIMITER ;
