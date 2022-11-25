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
 
 -- ------------------ Notification Posts ------------------
CREATE OR REPLACE VIEW notification_posts AS 
	SELECT 
			n.user_id AS user_id,
			u.first_name AS first_name,
			u.last_name AS last_name,
            p.post_id AS post_id,
			p.content AS content
        FROM notifications n
        INNER JOIN users u
			ON u.user_id = n.user_id
        INNER JOIN posts p
			ON p.user_id = n.user_id
        GROUP BY u.user_id, p.post_id
        ORDER BY u.user_id ASC;
        
SELECT * FROM notification_posts;


-- ------------------ Notify All ------------------

DELIMITER ;;
CREATE PROCEDURE notify_all(this_post_id INT UNSIGNED)

BEGIN

-- Get count of all users
    DECLARE user_count INT;
    DECLARE cur_user INT;
	SELECT COUNT(user_id) FROM users INTO user_count;
	SELECT user_id FROM users ORDER BY user_id DESC LIMIT 1 INTO cur_user;
    
    -- SET @current_post = (SELECT post_id FROM posts ORDER BY post_id DESC LIMIT 1);
	
    -- Loop through all users and add notification for them
    WHILE current_user < user_count + 1 DO
		INSERT INTO notifications
			(user_id, post_id)
		VALUES
			(cur_user, this_post_id);
		
        SET cur_user = cur_user + 1;
	END WHILE;
     
END;;
DELIMITER ;


-- ------------------ New User Added Trigger ------------------
-- When a new user is added, create a notification for everyone that states "{first_name} {last_name} just joined!" (for example: "Jeromy Streets just joined!").

DELIMITER ;;
CREATE TRIGGER user_added
	AFTER INSERT ON users
    FOR EACH ROW
BEGIN
	DECLARE first_name_new VARCHAR(30);
    DECLARE last_name_new VARCHAR(30);
    DECLARE this_post_id INT;
    DECLARE this_user_id INT;
	
    
    -- SELECT post_id + 1 FROM posts ORDER BY post_id DESC LIMIT 1 INTO this_post_id;
    
    SELECT user_id FROM users ORDER BY user_id DESC LIMIT 1 INTO this_user_id;
    SELECT first_name FROM users WHERE user_id = this_post_id INTO first_name_new;
    SELECT last_name FROM users WHERE user_id = this_post_id INTO last_name_new;

    
    INSERT INTO posts
		(user_id, content)
	VALUES
		-- (this_post_id, CONCAT(first_name_new, ' ', last_name_new, ' ', 'just joined!'));
        (this_user_id, 'just joined!');
        
	SELECT post_id FROM posts ORDER BY post_id DESC LIMIT 1 INTO this_post_id;
    
    SET this_post_id = this_post_id + 1;
        
	CALL notify_all(this_post_id);
        
END;;
DELIMITER ;
 
 
 

-- ------------------ Add Post Procedure ------------------ TODO: Fix

DELIMITER ;;
CREATE PROCEDURE add_post(user_id INT UNSIGNED, content VARCHAR(250))
BEGIN

    DECLARE friends_count INT;
    DECLARE this_post_id INT;
    
    -- Make Post
    INSERT INTO posts VALUES (user_id, content);
    
	-- Get count how many friends the user has
	SELECT COUNT(user_id) FROM friends WHERE user_id = user_id INTO friends_count;
    -- Get current post ID
    SELECT LAST_INSERT_ID() FROM posts INTO this_post_id;

    
    -- Make Notifications
    SET @current_user = 1;
    SET @current_post = this_post_id;
	
	WHILE @current_user < friends_count + 1 DO
		PREPARE notif_friends FROM 
			'INSERT INTO notifications 
				(user_id, post_id)
			VALUES
					(?, ?)';
		IF friends_count > 0 THEN
			EXECUTE notif_friends USING @current_user, @current_post;
		END IF;
		SET @current_user = @current_user + 1;
	END WHILE;

END;;
DELIMITER ;

INSERT INTO users
    (user_id, first_name, last_name, email)
VALUES
    (7, 'John', 'Moreau', 'name@someemail.com');
