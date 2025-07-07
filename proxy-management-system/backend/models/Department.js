const mongoose = require('mongoose');

const departmentSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Department name is required'],
    unique: true,
    trim: true,
    maxlength: [100, 'Department name cannot exceed 100 characters']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'Description cannot exceed 500 characters']
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual for getting all proxies in this department
departmentSchema.virtual('proxies', {
  ref: 'Proxy',
  localField: '_id',
  foreignField: 'departmentId'
});

// Virtual for getting all users in this department
departmentSchema.virtual('users', {
  ref: 'User',
  localField: '_id',
  foreignField: 'departmentId'
});

module.exports = mongoose.model('Department', departmentSchema);