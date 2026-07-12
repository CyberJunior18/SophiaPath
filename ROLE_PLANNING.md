# Plan for User Roles (React and Flutter)

This file shows how the React website and the Flutter mobile app will know what role a logged-in user has (like Student, Expert, Moderator, or Admin). 

It explains how to get the user's role from the backend database, save it on the user's device, and show or hide pages depending on the role.

---

## 1. How the Backend Sends User Roles

The backend database uses numbers to represent user roles:
*   **0** = Student (Regular student)
*   **1** = Expert (Teacher or course creator)
*   **2** = Moderator (Chat and community helper)
*   **3** = Admin (Full system owner)

When you ask the backend for the user profile (using `/users/me` or `/auth/profile`), the backend returns a JSON message that includes `roleID`:
```json
{
  "success": true,
  "data": {
    "id": 42,
    "email": "user@example.com",
    "username": "johndoe",
    "fullname": "John Doe",
    "roleID": 1, // 1 means this user is an Expert
    "xp": 150
  }
}
```

---

## 2. Flutter Mobile App Plan

Right now, the Flutter app gets user information from the backend but does not save or use the `roleID`. We need to add it.

### Step A: Create the Role List (Enum)
Create a new file `lib/models/user/user_role.dart` and add this code:

```dart
enum UserRole {
  student(0, 'Student'),
  expert(1, 'Expert'),
  moderator(2, 'Moderator'),
  admin(3, 'Admin');

  final int value;
  final String label;

  const UserRole(this.value, this.label);

  // This helper changes the backend number into a Flutter UserRole
  static UserRole fromInt(dynamic val) {
    final parsed = val is int ? val : int.tryParse(val?.toString() ?? '');
    switch (parsed) {
      case 1:
        return UserRole.expert;
      case 2:
        return UserRole.moderator;
      case 3:
        return UserRole.admin;
      case 0:
      default:
        return UserRole.student;
    }
  }
}
```

### Step B: Add Role to the `User` Model
Open `lib/models/user/user.dart` and add the `role` field. Here is what to change:

```dart
import 'user_role.dart';

class User {
  // ... Keep all other fields ...
  final UserRole role; // Add this line

  User({
    // ... Keep all other parameters ...
    this.role = UserRole.student, // Default is student
  });

  // Change toMap() to save the role number
  Map<String, dynamic> toMap() {
    return {
      // ... Keep all other map entries ...
      'roleID': role.value, // Save role number
    };
  }

  // Change fromMap() to read the role number from backend or local storage
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      // ... Keep all other fields ...
      role: UserRole.fromInt(map['roleID'] ?? map['role']),
    );
  }

  // Add role to copyWith()
  User copyWith({
    // ... Keep all other parameters ...
    UserRole? role,
  }) {
    return User(
      // ... Keep all other fields ...
      role: role ?? this.role,
    );
  }
}

// Add these helpers at the bottom of user.dart to make checking roles easy
extension UserRoleHelpers on User {
  bool get isStudent => role == UserRole.student;
  bool get isExpert => role == UserRole.expert;
  bool get isModerator => role == UserRole.moderator;
  bool get isAdmin => role == UserRole.admin;
}
```

### Step C: Save the Role on the Device
Open `lib/services/user_preferences_services.dart` and find `saveUserFromAuthProfile`. Change it so it reads and saves the user's role:

```dart
Future<bool> saveUserFromAuthProfile(Map<String, dynamic> profile) async {
  try {
    final source = profile['user'] is Map<String, dynamic>
        ? profile['user'] as Map<String, dynamic>
        : profile;

    final user = User(
      username: (source['username'] ?? '').toString(),
      fullName: (source['fullName'] ?? source['fullname'] ?? '').toString(),
      tag: (source['tag'] ?? 'Student').toString(),
      age: (source['age'] as num?)?.toInt() ?? 20,
      sex: (source['gender'] ?? source['sex'] ?? 'Rather not say').toString(),
      profileImage: (source['profilePicture'] ?? source['profileImage'] ?? source['avatar'] ?? User.defaultProfileImage).toString(),
      xp: (source['xp'] as num?)?.toInt() ?? 0,
      email: (source['email'] ?? source['Email'] ?? '').toString(),
      
      // Add this line to load and save the role
      role: UserRole.fromInt(source['roleID'] ?? source['role']), 
    );

    return await saveUser(user);
  } catch (e) {
    return false;
  }
}
```

### Step D: Show or Hide Flutter Widgets
You can now show or hide widgets based on the user's role.

```dart
Widget build(BuildContext context) {
  // Get the current user
  final user = context.watch<ProfileState>().currentUser;

  if (user == null) return const CircularProgressIndicator();

  return Scaffold(
    body: Column(
      children: [
        Text("Your Role is: ${user.role.label}"),
        
        // Show this widget ONLY if the user is an Expert
        if (user.isExpert) const Text("Show teacher dashboard tools here"),
        
        // Show this button ONLY if the user is an Admin
        if (user.isAdmin) ElevatedButton(
          onPressed: () {},
          child: const Text("Admin Panel"),
        ),
      ],
    ),
  );
}
```

---

## 3. React Web Frontend Plan

On the React website, we need to do similar steps using TypeScript and React Context.

### Step A: Define the User Role in TypeScript
Create or open a file like `src/types/user.ts` and write this code:

```typescript
// Define roles as numbers matching the backend
export enum UserRole {
  STUDENT = 0,
  EXPERT = 1,
  MODERATOR = 2,
  ADMIN = 3
}

export interface User {
  id: number;
  username: string;
  email: string;
  fullName: string;
  roleID: UserRole; // 0, 1, 2, or 3
}
```

### Step B: Save User Session (Auth Context)
Create a file `src/context/AuthContext.tsx` to handle user login, logout, and checking roles:

```typescript
import React, { createContext, useContext, useState, useEffect } from 'react';
import axios from 'axios';
import { User, UserRole } from '../types/user';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (token: string) => Promise<void>;
  logout: () => void;
  hasRole: (roles: UserRole[]) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  // Get user profile from backend using JWT token
  const fetchProfile = async (token: string) => {
    try {
      const response = await axios.get('/auth/profile', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setUser(response.data.data);
    } catch (err) {
      logout();
    } finally {
      setLoading(false);
    }
  };

  const login = async (token: string) => {
    localStorage.setItem('auth_token', token);
    await fetchProfile(token);
  };

  const logout = () => {
    localStorage.removeItem('auth_token');
    setUser(null);
    setLoading(false);
  };

  // Helper function to see if the user is allowed
  const hasRole = (allowedRoles: UserRole[]) => {
    if (!user) return false;
    return allowedRoles.includes(user.roleID);
  };

  useEffect(() => {
    const token = localStorage.getItem('auth_token');
    if (token) {
      fetchProfile(token);
    } else {
      setLoading(false);
    }
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, hasRole }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be inside AuthProvider');
  return context;
};
```

### Step C: Create a Simple Access Wrapper Component
Create a wrapper file `src/components/AllowedFor.tsx` to easily hide/show web page elements:

```typescript
import React from 'react';
import { useAuth } from '../context/AuthContext';
import { UserRole } from '../types/user';

interface AllowedForProps {
  roles: UserRole[];
  children: React.ReactNode;
}

export const AllowedFor: React.FC<AllowedForProps> = ({ roles, children }) => {
  const { hasRole } = useAuth();
  
  // If the user's role is in the list, show the child widgets. Else, show nothing.
  if (hasRole(roles)) {
    return <>{children}</>;
  }
  return null;
};
```

#### How to use this in your React pages:
```tsx
import React from 'react';
import { AllowedFor } from './components/AllowedFor';
import { UserRole } from './types/user';

export const Sidebar = () => {
  return (
    <div>
      <a href="/dashboard">My Lessons</a>

      {/* Only show to Expert or Admin */}
      <AllowedFor roles={[UserRole.EXPERT, UserRole.ADMIN]}>
        <a href="/edit-courses">Manage Course Material</a>
      </AllowedFor>

      {/* Only show to Admin */}
      <AllowedFor roles={[UserRole.ADMIN]}>
        <a href="/admin-settings">Admin Panel</a>
      </AllowedFor>
    </div>
  );
};
```

### Step D: Route Guarding (Protecting Web URLs)
Create a ProtectedRoute component to block users from typing a URL they are not allowed to see:

```typescript
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { UserRole } from '../types/user';

interface ProtectedRouteProps {
  allowedRoles?: UserRole[];
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ allowedRoles }) => {
  const { user, loading, hasRole } = useAuth();

  if (loading) return <div>Loading...</div>;

  // Not logged in -> go to login page
  if (!user) {
    return <Navigate to="/login" replace />;
  }

  // Logged in but wrong role -> go to unauthorized warning page
  if (allowedRoles && !hasRole(allowedRoles)) {
    return <Navigate to="/unauthorized" replace />;
  }

  // Role is correct -> show page
  return <Outlet />;
};
```

---

## 4. Key Rules to Remember

1.  **Backend is the real security boss**:
    Frontend guards (React and Flutter screens) are only to make the website/app look clean and hide buttons. A smart user can still hack the frontend. **Always make sure the NestJS backend has guards** to double-check user permissions on every API request.
2.  **Clear everything on logout**:
    When a user logs out, make sure to delete the JWT tokens and clear local cache memory so the next user does not accidentally see old pages.
