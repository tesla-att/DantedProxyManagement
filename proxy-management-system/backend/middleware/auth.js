const jwt = require('jsonwebtoken');
const User = require('../models/User');
const AuditLog = require('../models/AuditLog');

// Verify JWT token
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const user = await User.findById(decoded.id).populate('department');
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Invalid token or user is inactive.'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({
      success: false,
      message: 'Invalid token.'
    });
  }
};

// Check if user has required role
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.'
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Access forbidden. Insufficient permissions.'
      });
    }

    next();
  };
};

// Check if user can access specific department data
const checkDepartmentAccess = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required.'
    });
  }

  // Super admin can access everything
  if (req.user.role === 'SuperAdmin') {
    return next();
  }

  // Department manager can only access their own department
  if (req.user.role === 'DepartmentManager') {
    // If departmentId is in query params, check it
    if (req.query.departmentId && req.query.departmentId !== req.user.departmentId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Access forbidden. You can only access data from your department.'
      });
    }
    
    // Add department filter to request for automatic filtering
    req.departmentFilter = { departmentId: req.user.departmentId };
  }

  next();
};

// Audit log middleware
const auditLog = (action) => {
  return async (req, res, next) => {
    const originalSend = res.send;
    
    res.send = function(data) {
      // Only log successful operations (status 2xx)
      if (res.statusCode >= 200 && res.statusCode < 300) {
        const auditData = {
          userId: req.user._id,
          username: req.user.username,
          action: action,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent')
        };

        // Add target information if available
        if (req.targetId) {
          auditData.targetId = req.targetId;
          auditData.targetType = req.targetType;
        }

        // Add details if available
        if (req.auditDetails) {
          auditData.details = req.auditDetails;
        }

        // Log asynchronously to avoid blocking response
        AuditLog.logAction(auditData).catch(err => {
          console.error('Audit log error:', err);
        });
      }
      
      originalSend.call(this, data);
    };

    next();
  };
};

// Middleware to capture request data for audit logging
const captureAuditData = (req, res, next) => {
  // Store original data for comparison in audit logs
  if (req.method === 'PUT' || req.method === 'PATCH') {
    req.auditDetails = { before: req.originalData };
  }
  
  next();
};

module.exports = {
  authenticate,
  authorize,
  checkDepartmentAccess,
  auditLog,
  captureAuditData
};