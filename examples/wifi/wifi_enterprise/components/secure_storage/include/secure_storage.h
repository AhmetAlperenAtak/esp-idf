/**
 * @file secure_storage.h
 * @brief Secure NVS Storage Component for WiFi Credentials
 * 
 * This component handles encrypted storage and retrieval of sensitive data
 * Single Responsibility: Only NVS operations
 * 
 * @copyright Copyright (c) 2026 Industrial IoT Security
 */

#ifndef SECURE_STORAGE_H
#define SECURE_STORAGE_H

#include "esp_err.h"
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Load WiFi password from encrypted NVS storage
 * 
 * @param[out] password Buffer to store the password
 * @param[in]  max_len  Maximum length of the buffer
 * @return esp_err_t ESP_OK on success, error code otherwise
 */
esp_err_t secure_storage_load_wifi_password(char *password, size_t max_len);

/**
 * @brief Load device ID from NVS storage
 * 
 * @param[out] device_id Buffer to store the device ID
 * @param[in]  max_len   Maximum length of the buffer
 * @return esp_err_t ESP_OK on success, error code otherwise
 */
esp_err_t secure_storage_load_device_id(char *device_id, size_t max_len);

/**
 * @brief Securely erase data from memory
 * 
 * @param[in] data Pointer to data to be erased
 * @param[in] size Size of data to erase
 */
void secure_storage_clear_memory(void *data, size_t size);

#ifdef __cplusplus
}
#endif

#endif // SECURE_STORAGE_H
