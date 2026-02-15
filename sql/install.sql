CREATE TABLE IF NOT EXISTS `murderface_pets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `item_hash` VARCHAR(50) NOT NULL UNIQUE,
    `item_name` VARCHAR(50) NOT NULL,
    `metadata` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_hash` (`item_hash`)
);
