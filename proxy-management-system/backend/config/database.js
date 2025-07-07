const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log(`MongoDB Connected: ${conn.connection.host}`);
    
    // Create default admin user if it doesn't exist
    await createDefaultAdmin();
    
  } catch (error) {
    console.error('Database connection error:', error);
    process.exit(1);
  }
};

const createDefaultAdmin = async () => {
  try {
    const User = require('../models/User');
    const Department = require('../models/Department');
    
    // Check if admin user already exists
    const adminExists = await User.findOne({ role: 'SuperAdmin' });
    if (adminExists) {
      console.log('Admin user already exists');
      return;
    }

    // Create default department if it doesn't exist
    let defaultDept = await Department.findOne({ name: 'IT Department' });
    if (!defaultDept) {
      defaultDept = await Department.create({
        name: 'IT Department',
        description: 'Information Technology Department'
      });
      console.log('Default department created');
    }

    // Create admin user
    const adminUser = await User.create({
      username: process.env.ADMIN_USERNAME || 'admin',
      password: process.env.ADMIN_PASSWORD || 'admin123',
      role: 'SuperAdmin',
      email: process.env.EMAIL_USER || 'admin@company.com'
    });

    console.log('Default admin user created:', adminUser.username);
    
  } catch (error) {
    console.error('Error creating default admin:', error);
  }
};

module.exports = connectDB;