const { body, param, query } = require('express-validator');

// Auth validation rules
const loginValidation = [
  body('username')
    .trim()
    .notEmpty()
    .withMessage('Username is required')
    .isLength({ min: 3, max: 50 })
    .withMessage('Username must be between 3 and 50 characters'),
  
  body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters')
];

const changePasswordValidation = [
  body('currentPassword')
    .notEmpty()
    .withMessage('Current password is required'),
  
  body('newPassword')
    .isLength({ min: 6 })
    .withMessage('New password must be at least 6 characters')
    .custom((value, { req }) => {
      if (value === req.body.currentPassword) {
        throw new Error('New password must be different from current password');
      }
      return true;
    }),
  
  body('confirmPassword')
    .custom((value, { req }) => {
      if (value !== req.body.newPassword) {
        throw new Error('Password confirmation does not match new password');
      }
      return true;
    })
];

// Proxy validation rules
const createProxyValidation = [
  body('ipAddress')
    .notEmpty()
    .withMessage('IP address is required')
    .isIP()
    .withMessage('Please provide a valid IP address'),
  
  body('port')
    .isInt({ min: 1, max: 65535 })
    .withMessage('Port must be a number between 1 and 65535'),
  
  body('protocol')
    .isIn(['HTTP', 'HTTPS', 'SOCKS4', 'SOCKS5'])
    .withMessage('Protocol must be one of: HTTP, HTTPS, SOCKS4, SOCKS5'),
  
  body('username')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Username cannot exceed 100 characters'),
  
  body('password')
    .optional()
    .isLength({ max: 200 })
    .withMessage('Password cannot exceed 200 characters'),
  
  body('location')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Location cannot exceed 200 characters'),
  
  body('speed')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Speed must be a positive number'),
  
  body('status')
    .optional()
    .isIn(['Active', 'Inactive', 'Banned'])
    .withMessage('Status must be one of: Active, Inactive, Banned'),
  
  body('departmentId')
    .optional()
    .isMongoId()
    .withMessage('Department ID must be a valid MongoDB ObjectId'),
  
  body('expirationDate')
    .optional()
    .isISO8601()
    .withMessage('Expiration date must be a valid ISO date'),
  
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Notes cannot exceed 1000 characters'),
  
  body('tags')
    .optional()
    .isArray()
    .withMessage('Tags must be an array'),
  
  body('tags.*')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('Each tag cannot exceed 50 characters')
];

const updateProxyValidation = [
  param('id')
    .isMongoId()
    .withMessage('Invalid proxy ID'),
  
  body('ipAddress')
    .optional()
    .isIP()
    .withMessage('Please provide a valid IP address'),
  
  body('port')
    .optional()
    .isInt({ min: 1, max: 65535 })
    .withMessage('Port must be a number between 1 and 65535'),
  
  body('protocol')
    .optional()
    .isIn(['HTTP', 'HTTPS', 'SOCKS4', 'SOCKS5'])
    .withMessage('Protocol must be one of: HTTP, HTTPS, SOCKS4, SOCKS5'),
  
  body('username')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Username cannot exceed 100 characters'),
  
  body('password')
    .optional()
    .isLength({ max: 200 })
    .withMessage('Password cannot exceed 200 characters'),
  
  body('location')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Location cannot exceed 200 characters'),
  
  body('speed')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Speed must be a positive number'),
  
  body('status')
    .optional()
    .isIn(['Active', 'Inactive', 'Banned'])
    .withMessage('Status must be one of: Active, Inactive, Banned'),
  
  body('departmentId')
    .optional()
    .isMongoId()
    .withMessage('Department ID must be a valid MongoDB ObjectId'),
  
  body('expirationDate')
    .optional()
    .isISO8601()
    .withMessage('Expiration date must be a valid ISO date'),
  
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Notes cannot exceed 1000 characters'),
  
  body('tags')
    .optional()
    .isArray()
    .withMessage('Tags must be an array'),
  
  body('tags.*')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('Each tag cannot exceed 50 characters')
];

const proxyIdValidation = [
  param('id')
    .isMongoId()
    .withMessage('Invalid proxy ID')
];

// User validation rules
const createUserValidation = [
  body('username')
    .trim()
    .notEmpty()
    .withMessage('Username is required')
    .isLength({ min: 3, max: 50 })
    .withMessage('Username must be between 3 and 50 characters')
    .matches(/^[a-zA-Z0-9_.-]+$/)
    .withMessage('Username can only contain letters, numbers, dots, hyphens, and underscores'),
  
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
  
  body('role')
    .isIn(['SuperAdmin', 'DepartmentManager'])
    .withMessage('Role must be either SuperAdmin or DepartmentManager'),
  
  body('departmentId')
    .if(body('role').equals('DepartmentManager'))
    .notEmpty()
    .withMessage('Department ID is required for Department Manager role')
    .isMongoId()
    .withMessage('Department ID must be a valid MongoDB ObjectId'),
  
  body('email')
    .optional()
    .trim()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail()
];

const updateUserValidation = [
  param('id')
    .isMongoId()
    .withMessage('Invalid user ID'),
  
  body('username')
    .optional()
    .trim()
    .isLength({ min: 3, max: 50 })
    .withMessage('Username must be between 3 and 50 characters')
    .matches(/^[a-zA-Z0-9_.-]+$/)
    .withMessage('Username can only contain letters, numbers, dots, hyphens, and underscores'),
  
  body('password')
    .optional()
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
  
  body('role')
    .optional()
    .isIn(['SuperAdmin', 'DepartmentManager'])
    .withMessage('Role must be either SuperAdmin or DepartmentManager'),
  
  body('departmentId')
    .optional()
    .isMongoId()
    .withMessage('Department ID must be a valid MongoDB ObjectId'),
  
  body('email')
    .optional()
    .trim()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  
  body('isActive')
    .optional()
    .isBoolean()
    .withMessage('isActive must be a boolean value')
];

// Department validation rules
const createDepartmentValidation = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Department name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Department name must be between 2 and 100 characters'),
  
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description cannot exceed 500 characters')
];

const updateDepartmentValidation = [
  param('id')
    .isMongoId()
    .withMessage('Invalid department ID'),
  
  body('name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Department name must be between 2 and 100 characters'),
  
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description cannot exceed 500 characters')
];

// Query validation for pagination and filtering
const paginationValidation = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  
  query('sortBy')
    .optional()
    .isAlpha()
    .withMessage('Sort field must contain only letters'),
  
  query('sortOrder')
    .optional()
    .isIn(['asc', 'desc'])
    .withMessage('Sort order must be either asc or desc')
];

const proxyFilterValidation = [
  ...paginationValidation,
  
  query('status')
    .optional()
    .isIn(['Active', 'Inactive', 'Banned'])
    .withMessage('Status must be one of: Active, Inactive, Banned'),
  
  query('protocol')
    .optional()
    .isIn(['HTTP', 'HTTPS', 'SOCKS4', 'SOCKS5'])
    .withMessage('Protocol must be one of: HTTP, HTTPS, SOCKS4, SOCKS5'),
  
  query('departmentId')
    .optional()
    .isMongoId()
    .withMessage('Department ID must be a valid MongoDB ObjectId'),
  
  query('search')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Search term cannot exceed 100 characters')
];

// ID parameter validation
const idValidation = [
  param('id')
    .isMongoId()
    .withMessage('Invalid ID parameter')
];

module.exports = {
  // Auth
  loginValidation,
  changePasswordValidation,
  
  // Proxy
  createProxyValidation,
  updateProxyValidation,
  proxyIdValidation,
  proxyFilterValidation,
  
  // User
  createUserValidation,
  updateUserValidation,
  
  // Department
  createDepartmentValidation,
  updateDepartmentValidation,
  
  // General
  idValidation,
  paginationValidation
};