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

CREATE TABLE IF NOT EXISTS `murderface_stray_trust` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `stray_id` VARCHAR(50) NOT NULL,
    `trust` INT NOT NULL DEFAULT 0,
    `last_fed` TIMESTAMP NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_citizen_stray` (`citizenid`, `stray_id`),
    INDEX `idx_stray_id` (`stray_id`)
);

CREATE TABLE IF NOT EXISTS `murderface_doghouses` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `coords` VARCHAR(100) NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `placed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_citizen_doghouse` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `murderface_breeding` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `parent1_hash` VARCHAR(50) NOT NULL,
    `parent2_hash` VARCHAR(50) NOT NULL,
    `offspring_item` VARCHAR(50) NOT NULL,
    `offspring_metadata` LONGTEXT NOT NULL,
    `status` ENUM('pending','ready','claimed') NOT NULL DEFAULT 'pending',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizen_breeding` (`citizenid`),
    INDEX `idx_status` (`status`)
);
