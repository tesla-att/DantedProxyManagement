import React from 'react';
import { Box, Typography, Alert } from '@mui/material';

const Profile = () => {
  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        User Profile
      </Typography>
      <Alert severity="info">
        User profile and password change functionality will be implemented here.
        This page would allow users to view and update their profile information and change passwords.
      </Alert>
    </Box>
  );
};

export default Profile;