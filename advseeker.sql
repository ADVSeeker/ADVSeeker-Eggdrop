
CREATE TABLE IF NOT EXISTS `advseek` (
  `Section` text NOT NULL,
  `Field` text NOT NULL,
  `Value` text NOT NULL,
  FULLTEXT KEY `Section` (`Section`)
) TYPE=MyISAM;
INSERT INTO `advseek` VALUES ('Info', 'UpdateURL', 'http://www.skycommunity.lt/files/advseeker.update');
INSERT INTO `advseek` VALUES ('Info', 'UpdateInterval', '1');        