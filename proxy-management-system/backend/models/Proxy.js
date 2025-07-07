const mongoose = require('mongoose');
const crypto = require('crypto');

const proxySchema = new mongoose.Schema({
  ipAddress: {
    type: String,
    required: [true, 'IP Address is required'],
    validate: {
      validator: function(v) {
        return /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(v);
      },
      message: 'Please enter a valid IP address'
    }
  },
  port: {
    type: Number,
    required: [true, 'Port is required'],
    min: [1, 'Port must be between 1 and 65535'],
    max: [65535, 'Port must be between 1 and 65535']
  },
  protocol: {
    type: String,
    enum: ['HTTP', 'HTTPS', 'SOCKS4', 'SOCKS5'],
    required: [true, 'Protocol is required']
  },
  username: {
    type: String,
    trim: true,
    maxlength: [100, 'Username cannot exceed 100 characters']
  },
  password: {
    type: String,
    maxlength: [200, 'Password cannot exceed 200 characters']
  },
  location: {
    type: String,
    trim: true,
    maxlength: [200, 'Location cannot exceed 200 characters']
  },
  speed: {
    type: Number,
    min: [0, 'Speed cannot be negative'],
    default: 0
  },
  status: {
    type: String,
    enum: ['Active', 'Inactive', 'Banned'],
    default: 'Active'
  },
  departmentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Department',
    required: [true, 'Department is required']
  },
  expirationDate: {
    type: Date
  },
  notes: {
    type: String,
    maxlength: [1000, 'Notes cannot exceed 1000 characters']
  },
  tags: [{
    type: String,
    trim: true
  }],
  usage: {
    totalConnections: {
      type: Number,
      default: 0
    },
    lastUsed: {
      type: Date
    },
    monthlyTraffic: {
      type: Number,
      default: 0 // in MB
    }
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  updatedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Compound index for unique IP:Port combination
proxySchema.index({ ipAddress: 1, port: 1 }, { unique: true });

// Index for efficient queries
proxySchema.index({ departmentId: 1, status: 1 });
proxySchema.index({ expirationDate: 1 });

// Virtual for full address
proxySchema.virtual('fullAddress').get(function() {
  return `${this.ipAddress}:${this.port}`;
});

// Virtual for department details
proxySchema.virtual('department', {
  ref: 'Department',
  localField: 'departmentId',
  foreignField: '_id',
  justOne: true
});

// Encrypt password before saving
proxySchema.pre('save', function(next) {
  if (!this.isModified('password') || !this.password) return next();
  
  try {
    const algorithm = 'aes-256-cbc';
    const key = crypto.scryptSync(process.env.JWT_SECRET || 'default_secret', 'salt', 32);
    const iv = crypto.randomBytes(16);
    
    const cipher = crypto.createCipher(algorithm, key);
    let encrypted = cipher.update(this.password, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    this.password = encrypted;
    next();
  } catch (error) {
    next(error);
  }
});

// Decrypt password method
proxySchema.methods.getDecryptedPassword = function() {
  if (!this.password) return null;
  
  try {
    const algorithm = 'aes-256-cbc';
    const key = crypto.scryptSync(process.env.JWT_SECRET || 'default_secret', 'salt', 32);
    
    const decipher = crypto.createDecipher(algorithm, key);
    let decrypted = decipher.update(this.password, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  } catch (error) {
    return null;
  }
};

// Check if proxy is expiring soon
proxySchema.methods.isExpiringSoon = function(days = 7) {
  if (!this.expirationDate) return false;
  
  const warningDate = new Date();
  warningDate.setDate(warningDate.getDate() + days);
  
  return this.expirationDate <= warningDate;
};

module.exports = mongoose.model('Proxy', proxySchema);