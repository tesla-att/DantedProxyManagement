const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'User ID is required']
  },
  username: {
    type: String,
    required: [true, 'Username is required']
  },
  action: {
    type: String,
    enum: [
      'CREATE_PROXY',
      'UPDATE_PROXY', 
      'DELETE_PROXY',
      'ASSIGN_PROXY',
      'CREATE_USER',
      'UPDATE_USER',
      'DELETE_USER',
      'CREATE_DEPARTMENT',
      'UPDATE_DEPARTMENT',
      'DELETE_DEPARTMENT',
      'LOGIN',
      'LOGOUT',
      'EXPORT_DATA',
      'BULK_OPERATION'
    ],
    required: [true, 'Action is required']
  },
  targetId: {
    type: mongoose.Schema.Types.ObjectId,
    required: function() {
      return !['LOGIN', 'LOGOUT', 'EXPORT_DATA'].includes(this.action);
    }
  },
  targetType: {
    type: String,
    enum: ['Proxy', 'User', 'Department'],
    required: function() {
      return !['LOGIN', 'LOGOUT', 'EXPORT_DATA'].includes(this.action);
    }
  },
  details: {
    before: mongoose.Schema.Types.Mixed,
    after: mongoose.Schema.Types.Mixed,
    additionalInfo: mongoose.Schema.Types.Mixed
  },
  ipAddress: {
    type: String
  },
  userAgent: {
    type: String
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Index for efficient queries
auditLogSchema.index({ userId: 1, createdAt: -1 });
auditLogSchema.index({ action: 1, createdAt: -1 });
auditLogSchema.index({ targetId: 1, targetType: 1 });
auditLogSchema.index({ createdAt: -1 });

// Virtual for user details
auditLogSchema.virtual('user', {
  ref: 'User',
  localField: 'userId',
  foreignField: '_id',
  justOne: true
});

// Static method to log actions
auditLogSchema.statics.logAction = async function(actionData) {
  try {
    const log = new this(actionData);
    await log.save();
    return log;
  } catch (error) {
    console.error('Failed to create audit log:', error);
    return null;
  }
};

// Method to get human-readable action description
auditLogSchema.methods.getActionDescription = function() {
  const descriptions = {
    CREATE_PROXY: 'Created new proxy',
    UPDATE_PROXY: 'Updated proxy information',
    DELETE_PROXY: 'Deleted proxy',
    ASSIGN_PROXY: 'Assigned proxy to department',
    CREATE_USER: 'Created new user',
    UPDATE_USER: 'Updated user information',
    DELETE_USER: 'Deleted user',
    CREATE_DEPARTMENT: 'Created new department',
    UPDATE_DEPARTMENT: 'Updated department information',
    DELETE_DEPARTMENT: 'Deleted department',
    LOGIN: 'Logged in',
    LOGOUT: 'Logged out',
    EXPORT_DATA: 'Exported data',
    BULK_OPERATION: 'Performed bulk operation'
  };
  
  return descriptions[this.action] || this.action;
};

module.exports = mongoose.model('AuditLog', auditLogSchema);