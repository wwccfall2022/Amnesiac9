-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
    player_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL,
    email VARCHAR(50) NOT NULL
 );
 
 CREATE TABLE characters (
    character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    player_id INT UNSIGNED NOT NULL,
    name VARCHAR(30) NOT NULL,
    level INT UNSIGNED NOT NULL,
        FOREIGN KEY (player_id)
        REFERENCES players (player_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );
 
 CREATE TABLE winners (
    character_id INT UNSIGNED PRIMARY KEY NOT NULL,
    name VARCHAR(30) NOT NULL,
        FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );
 
  CREATE TABLE character_stats (
    character_id INT UNSIGNED PRIMARY KEY NOT NULL,
    health TINYINT SIGNED NOT NULL,
    armor TINYINT SIGNED NOT NULL,
        FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );
 
   CREATE TABLE teams (
    team_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name varchar(30) NOT NULL
 );
 
   CREATE TABLE team_members (
    team_member_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    team_id INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
        FOREIGN KEY (team_id)
        REFERENCES teams (team_id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
        FOREIGN KEY (team_id)
        REFERENCES teams (team_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

   CREATE TABLE items (
    item_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(30) NOT NULL,
    armor TINYINT UNSIGNED NOT NULL,
    damage TINYINT UNSIGNED NOT NULL
 );
 
    CREATE TABLE inventory (
    inventory_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
        FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
        FOREIGN KEY (item_id)
        REFERENCES items (item_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );
 
    CREATE TABLE equipped (
    equipped_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
        FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
        FOREIGN KEY (item_id)
        REFERENCES items (item_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );


-- Check all characters items in inventory and equiped.
CREATE OR REPLACE VIEW character_items AS 
	SELECT 
		c.character_id AS character_id,
        c.name AS character_name,
        i.name AS item_name,
        i.armor AS armor,
        i.damage AS damage
        FROM characters c
        INNER JOIN inventory inv
		ON inv.character_id = c.character_id
        INNER JOIN items i
	    ON i.item_id = inv.item_id
        INNER JOIN equipped eq
		ON eq.item_id = i.item_id
        GROUP BY c.character_id, eq.item_id
        ORDER BY c.character_id ASC;

-- SELECT * FROM character_view;

-- check teams items, doesn't duplicate items on the same team currently
CREATE OR REPLACE VIEW team_items AS 
	SELECT 
		t.team_id AS team_id,
        t.name AS team_name,
        i.name AS item_name,
        i.armor AS armor,
        i.damage AS damage
        FROM teams t
        INNER JOIN team_members tm
		ON t.team_id = tm.team_id
        INNER JOIN characters c
		ON tm.character_id = c.character_id
        INNER JOIN inventory inv
		ON inv.character_id = c.character_id
        INNER JOIN items i
		ON i.item_id = inv.item_id
GROUP BY t.team_id, inv.item_id;

-- SELECT * FROM team_items;


DELIMITER ;;
CREATE FUNCTION armor_total(character_id INT UNSIGNED)
    RETURNS INT UNSIGNED
    DETERMINISTIC
    BEGIN
		
        DECLARE total_armor TINYINT UNSIGNED;
        DECLARE stat_armor TINYINT UNSIGNED;
        DECLARE item_armor TINYINT UNSIGNED;
        
        SELECT i.armor
			INTO item_armor 
				FROM characters c
				INNER JOIN equipped eq
					ON c.character_id = eq.character_id
				INNER JOIN items i
					ON i.item_id = eq.item_id
			WHERE c.character_id=character_id
			GROUP BY c.character_id;
		
		IF item_armor > 0 THEN
			SELECT i.armor + cs.armor
			INTO total_armor 
				FROM characters c
				INNER JOIN equipped eq
					ON c.character_id = eq.character_id
				INNER JOIN items i
					ON i.item_id = eq.item_id
				INNER JOIN character_stats cs
					ON c.character_id = cs.character_id
			WHERE c.character_id=character_id
			GROUP BY c.character_id;
				
			RETURN total_armor;
		ELSE 
			
			SELECT cs.armor 
				INTO stat_armor 
					FROM characters c 
					INNER JOIN character_stats cs 
						ON c.character_id = cs.character_id 
				WHERE c.character_id=character_id 
				GROUP BY c.character_id;
        
			RETURN stat_armor;
		END IF;
        
	END;;
    DELIMITER ;
    
    --  SET @character_id=11;
	--  SELECT armor_total(@character_id) AS armor_total, name AS name FROM characters WHERE character_id=@character_id;
   
-- attack
DELIMITER ;;
CREATE PROCEDURE attack(target INT UNSIGNED, weapon INT UNSIGNED)
BEGIN
	
    DECLARE outcome VARCHAR(32);
    DECLARE char_armor TINYINT UNSIGNED;
    DECLARE wep_damage TINYINT UNSIGNED;
    DECLARE netdmg TINYINT SIGNED;
    DECLARE char_health TINYINT SIGNED;
    
    SELECT armor_total(target) INTO char_armor;
    SELECT damage INTO wep_damage FROM items WHERE item_id=weapon;

     IF wep_damage <= char_armor THEN
		-- SELECT 'Damage Blocked!' AS outcome;
        SELECT 'Damage Blocked!' INTO outcome;
	ELSE
		SELECT health INTO char_health FROM character_stats WHERE character_id=target;
		SELECT wep_damage - char_armor INTO netdmg;
		SET char_health = char_health - netdmg;
		UPDATE character_stats SET health=char_health WHERE character_id=target;
		-- SELECT 'Damage Taken!' AS outcome, netdmg AS damage_taken, char_health AS remaining_health;
        
		IF char_health < 1 THEN
			-- SELECT name AS name, 'Died' AS status FROM characters WHERE character_id=target;
			DELETE FROM characters WHERE character_id=target;
		END IF; 
        
	END IF;
   
    
END;;
DELIMITER ;

-- CALL attack(12, 9)

-- equip
DELIMITER ;;
CREATE PROCEDURE equip(equip_id INT UNSIGNED)
BEGIN
	
    DECLARE item INT UNSIGNED;
    DECLARE hero INT UNSIGNED;
    
	SELECT item_id INTO item FROM inventory WHERE inventory_id=equip_id;
    SELECT character_id INTO hero FROM inventory WHERE inventory_id=equip_id;
    
    IF item > 0 THEN
		INSERT INTO equipped (character_id, item_id) VALUES (hero, item);
       -- SELECT 'equipping...' AS task, name AS item FROM items WHERE item_id=item;
        DELETE FROM inventory WHERE inventory_id=equip_id;
    END IF;
    
END;;
DELIMITER ;

-- CALL equip(3);


-- unequip 
DELIMITER ;;
CREATE PROCEDURE unequip(unequip_id INT UNSIGNED)
BEGIN
	
    DECLARE item INT UNSIGNED;
    DECLARE hero INT UNSIGNED;
    
	SELECT item_id INTO item FROM equipped WHERE equipped_id=unequip_id;
    SELECT character_id INTO hero FROM equipped WHERE equipped_id=unequip_id;
    
    IF item > 0 THEN
		INSERT INTO inventory (character_id, item_id) VALUES (hero, item);
        -- SELECT 'unequipping...' AS task, name AS item FROM items WHERE item_id=item;
        DELETE FROM equipped WHERE equipped_id=unequip_id;
    END IF;
    
END;;
DELIMITER ;

-- CALL unequip(3);

-- set winners
DELIMITER ;;
CREATE PROCEDURE set_winners(team INT UNSIGNED)
BEGIN
	-- get character_id from team_members matching team_id and name from characters matching character_id and insert into winners

	DECLARE winners TINYINT UNSIGNED;
    
    SELECT COUNT(character_id) INTO winners FROM winners;
	
    -- deletes previous winners
	IF winners > 0 THEN
		TRUNCATE TABLE winners;
    END IF;

	INSERT INTO winners 
		SELECT c.character_id, c.name
			FROM characters c
			INNER JOIN team_members tm
			 ON tm.character_id = c.character_id
		WHERE tm.team_id = team;
    
END;;
DELIMITER ;

CALL set_winners(2);

SELECT * FROM winners;


