#!/bin/sh

# Enter the Omniport services directory
cd omniport/services

# Clone the Omniport services repositories from the remote
git clone https://github.com/IMGIITRoorkee/omniport-service-bootstrap.git bootstrap
git clone https://github.com/IMGIITRoorkee/omniport-service-functionality-tests.git functionality_tests