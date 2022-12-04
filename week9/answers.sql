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
 
 
 
-- ------------------ Notification Posts View ------------------

                
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

        
        
        
-- ------------------ Notify All Procedure ------------------

DELIMITER ;;
CREATE PROCEDURE notify_all(this_post_id INT UNSIGNED, new_user_id INT UNSIGNED)
BEGIN

	-- Variables
   -- DECLARE new_user_id INT;
    DECLARE cur_user INT;
    DECLARE row_not_found TINYINT DEFAULT FALSE;
    
	--  Users Cursor
	DECLARE users_cursor CURSOR FOR 
		SELECT user_id
			FROM users;
            
	DECLARE CONTINUE HANDLER FOR NOT FOUND
		SET row_not_found = TRUE;
	
	-- Get the latest users ID, this will be used to stop users getting a notification of their own joining.
	-- SELECT user_id FROM users ORDER BY user_id DESC LIMIT 1 INTO new_user_id; 
    
    -- Make Notifications for all users
    OPEN users_cursor;
    users_loop : LOOP
    
		FETCH users_cursor INTO cur_user;
        IF row_not_found THEN
			LEAVE users_loop;
		END IF;
        
        -- Insert notification row
        IF cur_user != new_user_id THEN
			INSERT INTO notifications (user_id, post_id) VALUES (cur_user, this_post_id);
		END IF;
        
        
	END LOOP users_loop;
    CLOSE users_cursor;
    
END;;





-- ------------------ Add Post Procedure ------------------ 


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




-- ------------------ New User Added Trigger ------------------


CREATE TRIGGER user_added
	AFTER INSERT ON users
    FOR EACH ROW
BEGIN

    DECLARE this_post_id INT;
    DECLARE new_user_id INT;
    
    -- Create Post about new user
    INSERT INTO posts
		(user_id, content)
	VALUES
		(NEW.user_id, CONCAT(NEW.first_name, ' ', NEW.last_name, ' ', 'just joined!'));
        
	SELECT LAST_INSERT_ID() FROM posts LIMIT 1 INTO this_post_id;
    SELECT NEW.user_id INTO new_user_id;
	
    -- Notify all users of new post
	CALL notify_all(this_post_id, new_user_id);
    
END;;

 
 
 
-- ------------------ EVENT LOG OUT ------------------  
-- Every 10 seconds, remove all sessions that haven't been updated in the last 2 hours.


CREATE EVENT two_hour_loggout
	ON SCHEDULE EVERY 10 SECOND
DO
BEGIN
		DELETE FROM sessions WHERE updated_on <= DATE_SUB(NOW(), INTERVAL 2 HOUR);
END;;
DELIMITER ;
