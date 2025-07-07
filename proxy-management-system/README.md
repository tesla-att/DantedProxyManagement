# Proxy Management System

A comprehensive centralized proxy management system that allows different departments within a company to efficiently use and manage proxies with proper security controls and audit trails.

## 🚀 Features

### Core Functionality
- **Centralized Proxy Management**: Manage all proxies from a single dashboard
- **Department-based Access Control**: Users can only access proxies assigned to their department
- **Role-based Permissions**: Super Admin and Department Manager roles with different access levels
- **Real-time Statistics**: Dashboard with charts showing proxy distribution and usage
- **Advanced Filtering**: Search and filter proxies by status, protocol, location, and more
- **Data Export**: Export proxy data to CSV format with applied filters
- **Audit Logging**: Complete audit trail of all system changes

### Security Features
- **JWT Authentication**: Secure token-based authentication
- **Password Encryption**: Proxy passwords are encrypted before storage
- **Rate Limiting**: Protection against brute force attacks
- **Input Validation**: Comprehensive validation on all endpoints
- **CORS Protection**: Configured for secure cross-origin requests

### Technical Features
- **Responsive Design**: Works seamlessly on desktop and mobile devices
- **Real-time Updates**: Auto-refresh capabilities for live data
- **Pagination**: Efficient handling of large datasets
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Health Monitoring**: Built-in health check endpoints

## 🏗️ Architecture

### Technology Stack
- **Backend**: Node.js, Express.js, MongoDB
- **Frontend**: React.js, Material-UI, React Query
- **Authentication**: JSON Web Tokens (JWT)
- **Database**: MongoDB with Mongoose ODM
- **Deployment**: Docker, Docker Compose

### Database Schema
- **Users**: User accounts with roles and department assignments
- **Departments**: Organizational departments
- **Proxies**: Proxy configurations with encrypted credentials
- **Audit Logs**: Complete change history

## 📋 Prerequisites

- Node.js 18+ and npm
- MongoDB 7+
- Docker and Docker Compose (for containerized deployment)

## 🚀 Quick Start

### Option 1: Docker Compose (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd proxy-management-system
   ```

2. **Start the application**
   ```bash
   docker-compose up -d
   ```

3. **Access the application**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:5000
   - MongoDB: localhost:27017

### Option 2: Manual Setup

#### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Start MongoDB**
   ```bash
   # Using MongoDB service
   sudo systemctl start mongod
   
   # Or using Docker
   docker run -d -p 27017:27017 --name mongodb mongo:7
   ```

5. **Start the backend**
   ```bash
   npm run dev
   ```

#### Frontend Setup

1. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start the frontend**
   ```bash
   npm start
   ```

## 🔐 Default Login Credentials

- **Username**: admin
- **Password**: admin123
- **Role**: Super Admin

## 📖 API Documentation

### Authentication Endpoints
- `POST /api/auth/login` - User login
- `GET /api/auth/me` - Get current user
- `POST /api/auth/change-password` - Change password
- `POST /api/auth/refresh` - Refresh JWT token

### Proxy Management Endpoints
- `GET /api/proxies` - Get all proxies (with filtering)
- `GET /api/proxies/stats` - Get proxy statistics
- `GET /api/proxies/export` - Export proxies to CSV
- `GET /api/proxies/:id` - Get proxy by ID
- `POST /api/proxies` - Create new proxy
- `PUT /api/proxies/:id` - Update proxy
- `DELETE /api/proxies/:id` - Delete proxy

### Health Check
- `GET /health` - Application health status

## 👥 User Roles

### Super Admin
- Full access to all system features
- Can manage all proxies across all departments
- Can view system-wide statistics and audit logs
- Can manage users and departments

### Department Manager
- Can only manage proxies assigned to their department
- Can view department-specific statistics
- Cannot access other departments' data
- Can export their department's proxy data

## 🛡️ Security Features

### Authentication & Authorization
- JWT-based authentication with configurable expiration
- Role-based access control (RBAC)
- Department-level data isolation
- Secure password hashing with bcrypt

### Data Protection
- Proxy passwords encrypted at rest
- Input validation and sanitization
- Rate limiting to prevent abuse
- CORS configuration for secure requests

### Audit & Monitoring
- Complete audit trail of all changes
- User activity logging
- Health monitoring endpoints
- Error tracking and reporting

## 🔧 Configuration

### Environment Variables

#### Backend (.env)
```env
# Server Configuration
PORT=5000
NODE_ENV=development

# Database Configuration
MONGODB_URI=mongodb://localhost:27017/proxy_management

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_here
JWT_EXPIRES_IN=7d

# Admin Configuration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Frontend URL
FRONTEND_URL=http://localhost:3000
```

## 🚀 Deployment

### Production Deployment

1. **Using Docker Compose**
   ```bash
   # Build and start all services
   docker-compose -f docker-compose.yml --profile production up -d
   ```

2. **Environment Configuration**
   - Update environment variables for production
   - Configure MongoDB with authentication
   - Set up SSL certificates for HTTPS
   - Configure reverse proxy (Nginx)

### Scaling Considerations
- Use MongoDB replica sets for high availability
- Implement Redis for session storage in multi-instance deployments
- Set up load balancing for multiple backend instances
- Configure CDN for static asset delivery

## 🧪 Testing

### Backend Testing
```bash
cd backend
npm test
```

### Frontend Testing
```bash
cd frontend
npm test
```

## 📊 Monitoring

### Health Checks
- Backend: `GET /health`
- Database connectivity monitoring
- Application performance metrics

### Logging
- Structured logging with Winston
- Request/response logging
- Error tracking and reporting
- Audit trail maintenance

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation for common issues

## 🎯 Roadmap

### Upcoming Features
- [ ] Advanced proxy health monitoring
- [ ] Automatic proxy rotation
- [ ] Integration with external proxy providers
- [ ] Advanced analytics and reporting
- [ ] Mobile application
- [ ] API rate limiting per department
- [ ] Proxy usage analytics
- [ ] Notification system for expiring proxies

### Technical Improvements
- [ ] GraphQL API implementation
- [ ] Real-time WebSocket updates
- [ ] Advanced caching strategies
- [ ] Microservices architecture
- [ ] Kubernetes deployment configuration

---

**Built with ❤️ for efficient proxy management**