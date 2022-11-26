-- Create your tables, views, functions and procedures here!
CREATE SCHEMA social;
USE social;

CREATE TABLE users (
    user_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL,
    email VARCHAR(50) NOT NULL,
    created_on TIMESTAMP NOT NULL DEFAULT NOW()
 );
 
 CREATE TABLE sessions (
    session_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    created_on TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
		FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );
 
  CREATE TABLE friends (
    user_friend_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    friend_id INT UNSIGNED NOT NULL,
		FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
		FOREIGN KEY (friend_id)
		REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
 );
 
   CREATE TABLE posts (
    post_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    created_on TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
    content VARCHAR(250) NOT NULL,
		FOREIGN KEY (user_id)
		REFERENCES users (user_id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
 );
 
    CREATE TABLE notifications (
    notification_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    post_id INT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
		FOREIGN KEY (user_id)
		REFERENCES users (user_id)
		ON UPDATE CASCADE
		ON DELETE CASCADE,
        FOREIGN KEY (post_id)
		REFERENCES posts (post_id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
 );
 
-- ------------------ Notification Posts ------------------ Currently shows any 1notifcations. TODO: Fix

CREATE OR REPLACE VIEW notification_posts AS 
	SELECT 
			n.user_id AS user_id,
			u.first_name AS first_name,
			u.last_name AS last_name,
            p.post_id AS post_id,
		 	p.content AS content
		FROM notifications n
			INNER JOIN posts p
				ON p.post_id = n.post_id
			RIGHT OUTER JOIN users u
				ON u.user_id = p.user_id;
        
        
        
-- ------------------ Notify All ------------------ WORKING

DELIMITER ;;
CREATE PROCEDURE notify_all(this_post_id INT UNSIGNED)

BEGIN

	-- Get count of all users
    DECLARE user_count INT;
    DECLARE cur_user INT;
    
	SELECT COUNT(user_id) FROM users INTO user_count;
    SET cur_user = 1;
	
    -- Loop through all users and add notification for them
    WHILE cur_user < user_count DO
		INSERT INTO notifications (user_id, post_id) VALUES (cur_user, this_post_id);
        SET cur_user = cur_user + 1;
	END WHILE;
     
END;;
DELIMITER ;



-- ------------------ New User Added Trigger ------------------ WORKING

DELIMITER ;;
CREATE TRIGGER user_added
	AFTER INSERT ON users
    FOR EACH ROW
BEGIN
	DECLARE first_name_new VARCHAR(30);
    DECLARE last_name_new VARCHAR(30);
    DECLARE this_post_id INT;
	
    SELECT first_name FROM users WHERE user_id = NEW.user_id INTO first_name_new;
    SELECT last_name FROM users WHERE user_id = NEW.user_id INTO last_name_new;

    
    INSERT INTO posts
		(user_id, content)
	VALUES
		(NEW.user_id, CONCAT(first_name_new, ' ', last_name_new, ' ', 'just joined!'));
        
	SELECT LAST_INSERT_ID() FROM posts LIMIT 1 INTO this_post_id;
        
	CALL notify_all(this_post_id);
        
END;;
DELIMITER ;
 
 
 
-- ------------------ Add Post Procedure ------------------ WORKING

DELIMITER ;;
CREATE PROCEDURE add_post(this_user_id INT UNSIGNED, this_content VARCHAR(250))
BEGIN
    DECLARE this_post_id INT;
    DECLARE cur_friend INT;
    DECLARE row_not_found TINYINT DEFAULT FALSE;
    
    --  Friends Cursor
    DECLARE friends_cursor CURSOR FOR 
		SELECT f.friend_id
			FROM friends f
            WHERE f.user_id = this_user_id
			ORDER BY f.friend_id ASC;
            
	-- Friends Cursor Row Not Found Handler
    DECLARE CONTINUE HANDLER FOR NOT FOUND
		SET row_not_found = TRUE;
    
    -- Make Post
    INSERT INTO posts (user_id, content) VALUES (this_user_id, this_content);

    -- Get current post ID
    SELECT LAST_INSERT_ID() FROM posts LIMIT 1 INTO this_post_id;
            
    -- Make Notifications
    OPEN friends_cursor;
    friends_loop : LOOP
    
		FETCH friends_cursor INTO cur_friend;
        IF row_not_found THEN
			LEAVE friends_loop;
		END IF;
        
        -- Insert notification row
        INSERT INTO notifications (user_id, post_id) VALUES (cur_friend, this_post_id);
        
	END LOOP friends_loop;
    CLOSE friends_cursor;

END;;
DELIMITER ;
