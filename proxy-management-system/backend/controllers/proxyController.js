const { validationResult } = require('express-validator');
const Proxy = require('../models/Proxy');
const Department = require('../models/Department');
const AuditLog = require('../models/AuditLog');
const csv = require('fast-csv');

// Get all proxies with filtering and pagination
const getProxies = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      status,
      protocol,
      location,
      departmentId,
      search,
      sortBy = 'createdAt',
      sortOrder = 'desc'
    } = req.query;

    // Build query object
    let query = {};

    // Apply department filter based on user role
    if (req.departmentFilter) {
      query = { ...query, ...req.departmentFilter };
    }

    // Apply additional filters
    if (status) query.status = status;
    if (protocol) query.protocol = protocol;
    if (location) query.location = { $regex: location, $options: 'i' };
    if (departmentId && req.user.role === 'SuperAdmin') {
      query.departmentId = departmentId;
    }

    // Search functionality
    if (search) {
      query.$or = [
        { ipAddress: { $regex: search, $options: 'i' } },
        { location: { $regex: search, $options: 'i' } },
        { notes: { $regex: search, $options: 'i' } },
        { tags: { $regex: search, $options: 'i' } }
      ];
    }

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === 'desc' ? -1 : 1;

    // Execute query
    const [proxies, total] = await Promise.all([
      Proxy.find(query)
        .populate('departmentId', 'name')
        .populate('createdBy', 'username')
        .populate('updatedBy', 'username')
        .sort(sortOptions)
        .skip(skip)
        .limit(parseInt(limit)),
      Proxy.countDocuments(query)
    ]);

    // Calculate pagination info
    const totalPages = Math.ceil(total / parseInt(limit));
    const currentPage = parseInt(page);

    res.json({
      success: true,
      data: {
        proxies,
        pagination: {
          currentPage,
          totalPages,
          totalItems: total,
          itemsPerPage: parseInt(limit),
          hasNextPage: currentPage < totalPages,
          hasPrevPage: currentPage > 1
        }
      }
    });

  } catch (error) {
    console.error('Get proxies error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching proxies'
    });
  }
};

// Get single proxy by ID
const getProxyById = async (req, res) => {
  try {
    const { id } = req.params;

    let query = { _id: id };
    
    // Apply department filter for department managers
    if (req.departmentFilter) {
      query = { ...query, ...req.departmentFilter };
    }

    const proxy = await Proxy.findOne(query)
      .populate('departmentId', 'name description')
      .populate('createdBy', 'username')
      .populate('updatedBy', 'username');

    if (!proxy) {
      return res.status(404).json({
        success: false,
        message: 'Proxy not found or access denied'
      });
    }

    res.json({
      success: true,
      data: { proxy }
    });

  } catch (error) {
    console.error('Get proxy by ID error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching proxy'
    });
  }
};

// Create new proxy
const createProxy = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation errors',
        errors: errors.array()
      });
    }

    const proxyData = req.body;

    // If user is department manager, force their department
    if (req.user.role === 'DepartmentManager') {
      proxyData.departmentId = req.user.departmentId;
    }

    // Verify department exists
    const department = await Department.findById(proxyData.departmentId);
    if (!department) {
      return res.status(400).json({
        success: false,
        message: 'Invalid department ID'
      });
    }

    // Add creator information
    proxyData.createdBy = req.user._id;
    proxyData.updatedBy = req.user._id;

    const proxy = new Proxy(proxyData);
    await proxy.save();

    // Populate the response
    await proxy.populate('departmentId', 'name');
    await proxy.populate('createdBy', 'username');

    // Set audit information
    req.targetId = proxy._id;
    req.targetType = 'Proxy';
    req.auditDetails = { after: proxy.toObject() };

    res.status(201).json({
      success: true,
      message: 'Proxy created successfully',
      data: { proxy }
    });

  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Proxy with this IP:Port combination already exists'
      });
    }

    console.error('Create proxy error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while creating proxy'
    });
  }
};

// Update proxy
const updateProxy = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation errors',
        errors: errors.array()
      });
    }

    const { id } = req.params;
    const updateData = req.body;

    // Find existing proxy with department access check
    let query = { _id: id };
    if (req.departmentFilter) {
      query = { ...query, ...req.departmentFilter };
    }

    const existingProxy = await Proxy.findOne(query);
    if (!existingProxy) {
      return res.status(404).json({
        success: false,
        message: 'Proxy not found or access denied'
      });
    }

    // Store original data for audit
    const originalData = existingProxy.toObject();

    // Department managers cannot change department
    if (req.user.role === 'DepartmentManager') {
      delete updateData.departmentId;
    }

    // Verify department exists if being changed
    if (updateData.departmentId) {
      const department = await Department.findById(updateData.departmentId);
      if (!department) {
        return res.status(400).json({
          success: false,
          message: 'Invalid department ID'
        });
      }
    }

    // Add updater information
    updateData.updatedBy = req.user._id;

    const proxy = await Proxy.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true
    }).populate('departmentId', 'name').populate('updatedBy', 'username');

    // Set audit information
    req.targetId = proxy._id;
    req.targetType = 'Proxy';
    req.auditDetails = {
      before: originalData,
      after: proxy.toObject()
    };

    res.json({
      success: true,
      message: 'Proxy updated successfully',
      data: { proxy }
    });

  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Proxy with this IP:Port combination already exists'
      });
    }

    console.error('Update proxy error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while updating proxy'
    });
  }
};

// Delete proxy
const deleteProxy = async (req, res) => {
  try {
    const { id } = req.params;

    // Find existing proxy with department access check
    let query = { _id: id };
    if (req.departmentFilter) {
      query = { ...query, ...req.departmentFilter };
    }

    const proxy = await Proxy.findOne(query).populate('departmentId', 'name');
    if (!proxy) {
      return res.status(404).json({
        success: false,
        message: 'Proxy not found or access denied'
      });
    }

    // Store data for audit
    const deletedData = proxy.toObject();

    await Proxy.findByIdAndDelete(id);

    // Set audit information
    req.targetId = id;
    req.targetType = 'Proxy';
    req.auditDetails = { before: deletedData };

    res.json({
      success: true,
      message: 'Proxy deleted successfully'
    });

  } catch (error) {
    console.error('Delete proxy error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while deleting proxy'
    });
  }
};

// Export proxies to CSV
const exportProxies = async (req, res) => {
  try {
    // Use same filtering logic as getProxies
    let query = {};
    if (req.departmentFilter) {
      query = { ...query, ...req.departmentFilter };
    }

    const { status, protocol, location, departmentId } = req.query;
    
    if (status) query.status = status;
    if (protocol) query.protocol = protocol;
    if (location) query.location = { $regex: location, $options: 'i' };
    if (departmentId && req.user.role === 'SuperAdmin') {
      query.departmentId = departmentId;
    }

    const proxies = await Proxy.find(query)
      .populate('departmentId', 'name')
      .lean();

    // Transform data for CSV export
    const csvData = proxies.map(proxy => ({
      'IP Address': proxy.ipAddress,
      'Port': proxy.port,
      'Full Address': `${proxy.ipAddress}:${proxy.port}`,
      'Protocol': proxy.protocol,
      'Username': proxy.username || '',
      'Location': proxy.location || '',
      'Speed (Mbps)': proxy.speed,
      'Status': proxy.status,
      'Department': proxy.departmentId?.name || '',
      'Tags': proxy.tags?.join(', ') || '',
      'Expiration Date': proxy.expirationDate ? new Date(proxy.expirationDate).toLocaleDateString() : '',
      'Created At': new Date(proxy.createdAt).toLocaleDateString(),
      'Notes': proxy.notes || ''
    }));

    // Set CSV headers
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="proxies-export-${new Date().toISOString().split('T')[0]}.csv"`);

    // Write CSV
    csv.writeToString(csvData, { headers: true }, (err, data) => {
      if (err) {
        console.error('CSV export error:', err);
        return res.status(500).json({
          success: false,
          message: 'Error generating CSV export'
        });
      }
      
      res.send(data);
    });

  } catch (error) {
    console.error('Export proxies error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while exporting proxies'
    });
  }
};

// Get proxy statistics
const getProxyStats = async (req, res) => {
  try {
    let query = {};
    if (req.departmentFilter) {
      query = { ...query, ...req.departmentFilter };
    }

    const [
      totalProxies,
      activeProxies,
      inactiveProxies,
      bannedProxies,
      expiringProxies,
      protocolStats,
      departmentStats
    ] = await Promise.all([
      Proxy.countDocuments(query),
      Proxy.countDocuments({ ...query, status: 'Active' }),
      Proxy.countDocuments({ ...query, status: 'Inactive' }),
      Proxy.countDocuments({ ...query, status: 'Banned' }),
      Proxy.countDocuments({
        ...query,
        expirationDate: {
          $lte: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        }
      }),
      Proxy.aggregate([
        { $match: query },
        { $group: { _id: '$protocol', count: { $sum: 1 } } }
      ]),
      req.user.role === 'SuperAdmin' ? 
        Proxy.aggregate([
          { $match: query },
          { $lookup: { from: 'departments', localField: 'departmentId', foreignField: '_id', as: 'department' } },
          { $unwind: '$department' },
          { $group: { _id: '$department.name', count: { $sum: 1 } } }
        ]) : []
    ]);

    res.json({
      success: true,
      data: {
        overview: {
          total: totalProxies,
          active: activeProxies,
          inactive: inactiveProxies,
          banned: bannedProxies,
          expiring: expiringProxies
        },
        protocolDistribution: protocolStats,
        departmentDistribution: departmentStats
      }
    });

  } catch (error) {
    console.error('Get proxy stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching statistics'
    });
  }
};

module.exports = {
  getProxies,
  getProxyById,
  createProxy,
  updateProxy,
  deleteProxy,
  exportProxies,
  getProxyStats
};