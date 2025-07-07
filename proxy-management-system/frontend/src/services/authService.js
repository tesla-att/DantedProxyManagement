import api from './api';

class AuthService {
  async login(credentials) {
    const response = await api.post('/auth/login', credentials);
    return response.data.data;
  }

  async getCurrentUser() {
    const response = await api.get('/auth/me');
    return response.data.data.user;
  }

  async changePassword(passwordData) {
    const response = await api.post('/auth/change-password', passwordData);
    return response.data;
  }

  async refreshToken() {
    const response = await api.post('/auth/refresh');
    return response.data.data;
  }
}

export default new AuthService();