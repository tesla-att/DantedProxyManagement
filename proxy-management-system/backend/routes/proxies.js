const express = require('express');
const router = express.Router();
const proxyController = require('../controllers/proxyController');
const { 
  authenticate, 
  authorize, 
  checkDepartmentAccess,
  auditLog 
} = require('../middleware/auth');
const {
  createProxyValidation,
  updateProxyValidation,
  proxyIdValidation,
  proxyFilterValidation
} = require('../utils/validation');

// Apply authentication to all routes
router.use(authenticate);

// @route   GET /api/proxies
// @desc    Get all proxies with filtering and pagination
// @access  Private (SuperAdmin: all, DepartmentManager: own department)
router.get('/', 
  checkDepartmentAccess,
  proxyFilterValidation,
  proxyController.getProxies
);

// @route   GET /api/proxies/stats
// @desc    Get proxy statistics
// @access  Private (SuperAdmin: all, DepartmentManager: own department)
router.get('/stats',
  checkDepartmentAccess,
  proxyController.getProxyStats
);

// @route   GET /api/proxies/export
// @desc    Export proxies to CSV
// @access  Private (SuperAdmin: all, DepartmentManager: own department)
router.get('/export',
  checkDepartmentAccess,
  auditLog('EXPORT_DATA'),
  proxyController.exportProxies
);

// @route   GET /api/proxies/:id
// @desc    Get single proxy by ID
// @access  Private (SuperAdmin: all, DepartmentManager: own department)
router.get('/:id',
  proxyIdValidation,
  checkDepartmentAccess,
  proxyController.getProxyById
);

// @route   POST /api/proxies
// @desc    Create new proxy
// @access  Private (Both roles, but DepartmentManager limited to own department)
router.post('/',
  authorize('SuperAdmin', 'DepartmentManager'),
  checkDepartmentAccess,
  createProxyValidation,
  auditLog('CREATE_PROXY'),
  proxyController.createProxy
);

// @route   PUT /api/proxies/:id
// @desc    Update proxy
// @access  Private (SuperAdmin: all, DepartmentManager: own department only)
router.put('/:id',
  authorize('SuperAdmin', 'DepartmentManager'),
  checkDepartmentAccess,
  updateProxyValidation,
  auditLog('UPDATE_PROXY'),
  proxyController.updateProxy
);

// @route   DELETE /api/proxies/:id
// @desc    Delete proxy
// @access  Private (SuperAdmin: all, DepartmentManager: own department only)
router.delete('/:id',
  authorize('SuperAdmin', 'DepartmentManager'),
  checkDepartmentAccess,
  proxyIdValidation,
  auditLog('DELETE_PROXY'),
  proxyController.deleteProxy
);

module.exports = router;