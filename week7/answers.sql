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
    name VARCHAR(30) NOT NULL
 );
 
   CREATE TABLE team_members (
    team_member_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    team_id INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
        FOREIGN KEY (team_id)
        REFERENCES teams (team_id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
        FOREIGN KEY (character_id)
        REFERENCES characters (character_id)
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
 

-- ------------------ CHARACTER INVENTORY CHECK ------------------
CREATE OR REPLACE VIEW character_equipped AS 
	SELECT 
			c.character_id AS character_id,
			c.name AS character_name,
			i.name AS item_name,
            i.item_id AS item_id, -- ADDED THIS
			i.armor AS armor,
			i.damage AS damage
        FROM characters c
        INNER JOIN equipped eq
			ON eq.character_id = c.character_id
        INNER JOIN items i
			ON eq.item_id = i.item_id
        GROUP BY c.character_id, eq.item_id
        ORDER BY c.character_id ASC;
        
CREATE OR REPLACE VIEW character_inv AS 
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
			ON inv.item_id = i.item_id
        GROUP BY c.character_id, inv.item_id
        ORDER BY c.character_id ASC;
        
CREATE OR REPLACE VIEW character_items AS
 	SELECT 
			ce.character_id AS character_id,
			ce.character_name AS character_name,
			ce.item_name AS item_name,
			ce.armor AS armor,
			ce.damage AS damage
        FROM character_equipped ce
		UNION
	SELECT
			ci.character_id AS character_id,
			ci.character_name AS character_name,
			ci.item_name AS item_name,
			ci.armor AS armor,
			ci.damage AS damage
        FROM character_inv ci
	ORDER BY item_name;
	

-- ----------------- TEAM INVENTORY CHECK ------------------
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


-- ------------------------- ARMOR TOTAL FUNCTION ----------------------------
DELIMITER ;;
CREATE FUNCTION armor_total(character_id INT UNSIGNED)
    RETURNS INT UNSIGNED
    DETERMINISTIC
    BEGIN
		
        DECLARE total_armor INT UNSIGNED;
        DECLARE stat_armor INT UNSIGNED;
        DECLARE item_armor INT UNSIGNED;
        
		SELECT SUM(i.armor)
			INTO item_armor 
				FROM characters c
				INNER JOIN equipped eq
					ON c.character_id = eq.character_id
				INNER JOIN items i
					ON i.item_id = eq.item_id
			WHERE c.character_id=character_id
		
		SELECT cs.armor 
			INTO stat_armor 
				FROM characters c 
				INNER JOIN character_stats cs 
					ON c.character_id = cs.character_id 
			WHERE c.character_id=character_id 
        
		IF item_armor > 0 THEN
			SET total_armor = (item_armor + stat_armor);
			RETURN total_armor;
		ELSE 
			RETURN stat_armor;
		END IF;
END;;
DELIMITER ;
    
    
-- ------------------------------- Attack Procedure -------------------------
DELIMITER ;;
CREATE PROCEDURE attack(target INT UNSIGNED, chosen_weapon INT UNSIGNED)
BEGIN
	
    DECLARE outcome VARCHAR(32);
    DECLARE char_armor TINYINT UNSIGNED;
    DECLARE wep_damage TINYINT UNSIGNED;
	DECLARE weapon TINYINT UNSIGNED;
    DECLARE netdmg TINYINT SIGNED;
    DECLARE char_health TINYINT SIGNED;
    
    SELECT armor_total(target) INTO char_armor;
    SELECT item_id INTO weapon FROM equipped WHERE equipped_id = chosen_weapon;
    SELECT damage INTO wep_damage FROM items WHERE item_id = weapon;

     IF wep_damage <= char_armor THEN
		SELECT 'Damage Blocked!' AS outcome;
	ELSE
		SELECT health INTO char_health FROM character_stats WHERE character_id=target;
		SELECT wep_damage - char_armor INTO netdmg;
		SET char_health = char_health - netdmg;
		UPDATE character_stats SET health=char_health WHERE character_id=target;
		-- SELECT 'Damage Taken!' AS outcome, netdmg AS damage_taken, char_health AS remaining_health;
        
		IF char_health < 1 THEN
			DELETE FROM characters WHERE character_id=target;
		END IF; 
        
	END IF;
   
    
END;;
DELIMITER ;

-- ------------------- Equip -----------------------
DELIMITER ;;
CREATE PROCEDURE equip(equip_id INT UNSIGNED)
BEGIN
	
    DECLARE item INT UNSIGNED;
    DECLARE hero INT UNSIGNED;
    
	SELECT item_id INTO item FROM inventory WHERE inventory_id=equip_id;
    SELECT character_id INTO hero FROM inventory WHERE inventory_id=equip_id;
    
    IF item > 0 THEN
		INSERT INTO equipped (character_id, item_id) VALUES (hero, item);
        DELETE FROM inventory WHERE inventory_id=equip_id;
    END IF;
    
END;;
DELIMITER ;


-- ------------------ Unequip ----------------------------
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


-- -------------------------- set winners -----------------------
DELIMITER ;;
CREATE PROCEDURE set_winners(team INT UNSIGNED)
BEGIN

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

