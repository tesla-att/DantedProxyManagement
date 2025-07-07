import React from 'react';
import { Box, Typography, Alert } from '@mui/material';

const CreateProxy = () => {
  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Create New Proxy
      </Typography>
      <Alert severity="info">
        Create proxy functionality will be implemented here.
        This page would contain a form with all proxy fields including IP, port, protocol, department assignment, etc.
      </Alert>
    </Box>
  );
};

export default CreateProxy;