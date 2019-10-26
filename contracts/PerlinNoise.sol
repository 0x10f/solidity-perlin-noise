pragma solidity ^0.5.0;

/**
 * @notice An implementation of Perlin Noise that uses 16 bit fixed point arithmetic.
 */
library PerlinNoise {

    /**
     * @notice Computes the noise value for a 2D point.
     *
     * @param x the x coordinate.
     * @param y the y coordinate.
     *
     * @dev This function should be kept public. Inlining the bytecode for this function
     *      into other functions could explode its compiled size because of how `ftable`
     *      and `ptable` were written.
     */
    function noise2d(int256 x, int256 y) public pure returns (int256) {
        int256[6] memory scratch;

        scratch[0] = x >> 16 & 0xff;  // Unit square X
        scratch[1] = y >> 16 & 0xff;  // Unit square Y

        x &= 0xffff; // Square relative X
        y &= 0xffff; // Square relative Y

        int256 temp = ptable(scratch[0]) + scratch[1];

        scratch[2] = ptable(temp);
        scratch[3] = ptable(temp + 1);

        temp = ptable(scratch[0] + 1) + scratch[1];

        scratch[4] = ptable(temp    );
        scratch[5] = ptable(temp + 1);

        int256 a;
        int256 b;

        int256 u = fade(x);

        a = lerp(u, grad2(scratch[2], x, y        ), grad2(scratch[4], x-0x10000, y        ));
        b = lerp(u, grad2(scratch[3], x, y-0x10000), grad2(scratch[5], x-0x10000, y-0x10000));

        return lerp(fade(y), a, b);
    }

    /**
     * @notice Computes the noise value for a 3D point.
     *
     * @param x the x coordinate.
     * @param y the y coordinate.
     * @param z the z coordinate.
     *
     * @dev This function should be kept public. Inlining the bytecode for this function
     *      into other functions could explode its compiled size because of how `ftable`
     *      and `ptable` were written.
     */
    function noise3d(int256 x, int256 y, int256 z) public pure returns (int256) {
        int256[7] memory scratch = [
            x >> 16 & 0xff,  // Unit cube X
            y >> 16 & 0xff,  // Unit cube Y
            z >> 16 & 0xff,  // Unit cube Z
            0, 0, 0, 0
        ];

        x &= 0xffff; // Cube relative X
        y &= 0xffff; // Cube relative Y
        z &= 0xffff; // Cube relative Z

        scratch[3] = ptable((ptable(scratch[0]    ) + scratch[1]    )) + scratch[2];
        scratch[4] = ptable((ptable(scratch[0]    ) + scratch[1] + 1)) + scratch[2];
        scratch[5] = ptable((ptable(scratch[0] + 1) + scratch[1]    )) + scratch[2];
        scratch[6] = ptable((ptable(scratch[0] + 1) + scratch[1] + 1)) + scratch[2];

        int256 a;
        int256 b;
        int256 c;

        int256 u = fade(x);
        int256 v = fade(y);

        a = lerp(u, grad3(ptable(scratch[3]), x, y        , z), grad3(ptable(scratch[5]), x-0x10000, y        , z));
        b = lerp(u, grad3(ptable(scratch[4]), x, y-0x10000, z), grad3(ptable(scratch[6]), x-0x10000, y-0x10000, z));
        c = lerp(v, a, b);

        a = lerp(u, grad3(ptable(scratch[3]+1), x, y        , z-0x10000), grad3(ptable(scratch[5]+1), x-0x10000, y        , z-0x10000));
        b = lerp(u, grad3(ptable(scratch[4]+1), x, y-0x10000, z-0x10000), grad3(ptable(scratch[6]+1), x-0x10000, y-0x10000, z-0x10000));

        return lerp(fade(z), c, lerp(v, a, b));
    }

    /**
     * @notice Computes the linear interpolation between two values, `a` and `b`, using fixed point arithmetic.
     *
     * @param t the time value of the equation.
     * @param a the lower point.
     * @param b the upper point.
     */
    function lerp(int256 t, int256 a, int256 b) internal pure returns (int256) {
        return a + (t * (b - a) >> 12);
    }

    /**
     * @notice Applies the fade function to a value.
     *
     * @param t the time value of the equation.
     *
     * @dev The polynomial for this function is: 6t^4-15t^4+10t^3.
     */
    function fade(int256 t) internal pure returns (int256) {
        int256 n = ftable(t >> 8);

        // Lerp between the two points grabbed from the fade table.
        (int256 lower, int256 upper) = (n >> 12, n & 0xfff);
        return lower + ((t & 0xff) * (upper - lower) >> 8);
    }

    /**
      * @notice Computes the gradient value for a 2D point.
      *
      * @param h the hash value to use for picking the vector.
      * @param x the x coordinate of the point.
      * @param y the y coordinate of the point.
      */
    function grad2(int256 h, int256 x, int256 y) internal pure returns (int256) {
        h &= 3;

        int256 u;
        if (h & 0x1 == 0) {
            u = x;
        } else {
            u = -x;
        }

        int256 v;
        if (h < 2) {
            v = y;
        } else {
            v = -y;
        }

        return u + v;
    }

    /**
     * @notice Computes the gradient value for a 3D point.
     *
     * @param h the hash value to use for picking the vector.
     * @param x the x coordinate of the point.
     * @param y the y coordinate of the point.
     * @param z the z coordinate of the point.
     */
    function grad3(int256 h, int256 x, int256 y, int256 z) internal pure returns (int256) {
        h &= 0xf;

        int256 u;
        if (h < 8) {
            u = x;
        } else {
            u = y;
        }

        int256 v;
        if (h < 4) {
            v = y;
        } else if (h == 12 || h == 14) {
            v = x;
        } else {
            v = z;
        }

        if ((h & 0x1) != 0) {
            u = -u;
        }

        if ((h & 0x2) != 0) {
            v = -v;
        }

        return u + v;
    }

    /**
     * @notice Gets a value in the permutation table.
     *
     * @param i the index in the permutation table.
     *
     * @dev The values from the table are mapped out into a binary tree for faster lookups.
     *      Looking up any value in the table in this implementation is is O(8), in
     *      the implementation of sequential if statements it is O(255).
     *
     * @dev The body of this function is autogenerated. Check out the 'gen-ptable' script.
     */
    function ptable(int256 i) internal pure returns (int256) {
        i &= 0xff;

        if (i <= 127) {
            if (i <= 63) {
                if (i <= 31) {
                    if (i <= 15) {
                        if (i <= 7) {
                            if (i <= 3) {
                                if (i <= 1) {
                                    if (i == 0) {
                                        return 151;
                                    } else {
                                        return 160;
                                    }
                                } else {
                                    if (i == 2) {
                                        return 137;
                                    } else {
                                        return 91;
                                    }
                                }
                            } else {
                                if (i <= 5) {
                                    if (i == 4) {
                                        return 90;
                                    } else {
                                        return 15;
                                    }
                                } else {
                                    if (i == 6) {
                                        return 131;
                                    } else {
                                        return 13;
                                    }
                                }
                            }
                        } else {
                            if (i <= 11) {
                                if (i <= 9) {
                                    if (i == 8) {
                                        return 201;
                                    } else {
                                        return 95;
                                    }
                                } else {
                                    if (i == 10) {
                                        return 96;
                                    } else {
                                        return 53;
                                    }
                                }
                            } else {
                                if (i <= 13) {
                                    if (i == 12) {
                                        return 194;
                                    } else {
                                        return 233;
                                    }
                                } else {
                                    if (i == 14) {
                                        return 7;
                                    } else {
                                        return 225;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 23) {
                            if (i <= 19) {
                                if (i <= 17) {
                                    if (i == 16) {
                                        return 140;
                                    } else {
                                        return 36;
                                    }
                                } else {
                                    if (i == 18) {
                                        return 103;
                                    } else {
                                        return 30;
                                    }
                                }
                            } else {
                                if (i <= 21) {
                                    if (i == 20) {
                                        return 69;
                                    } else {
                                        return 142;
                                    }
                                } else {
                                    if (i == 22) {
                                        return 8;
                                    } else {
                                        return 99;
                                    }
                                }
                            }
                        } else {
                            if (i <= 27) {
                                if (i <= 25) {
                                    if (i == 24) {
                                        return 37;
                                    } else {
                                        return 240;
                                    }
                                } else {
                                    if (i == 26) {
                                        return 21;
                                    } else {
                                        return 10;
                                    }
                                }
                            } else {
                                if (i <= 29) {
                                    if (i == 28) {
                                        return 23;
                                    } else {
                                        return 190;
                                    }
                                } else {
                                    if (i == 30) {
                                        return 6;
                                    } else {
                                        return 148;
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 47) {
                        if (i <= 39) {
                            if (i <= 35) {
                                if (i <= 33) {
                                    if (i == 32) {
                                        return 247;
                                    } else {
                                        return 120;
                                    }
                                } else {
                                    if (i == 34) {
                                        return 234;
                                    } else {
                                        return 75;
                                    }
                                }
                            } else {
                                if (i <= 37) {
                                    if (i == 36) {
                                        return 0;
                                    } else {
                                        return 26;
                                    }
                                } else {
                                    if (i == 38) {
                                        return 197;
                                    } else {
                                        return 62;
                                    }
                                }
                            }
                        } else {
                            if (i <= 43) {
                                if (i <= 41) {
                                    if (i == 40) {
                                        return 94;
                                    } else {
                                        return 252;
                                    }
                                } else {
                                    if (i == 42) {
                                        return 219;
                                    } else {
                                        return 203;
                                    }
                                }
                            } else {
                                if (i <= 45) {
                                    if (i == 44) {
                                        return 117;
                                    } else {
                                        return 35;
                                    }
                                } else {
                                    if (i == 46) {
                                        return 11;
                                    } else {
                                        return 32;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 55) {
                            if (i <= 51) {
                                if (i <= 49) {
                                    if (i == 48) {
                                        return 57;
                                    } else {
                                        return 177;
                                    }
                                } else {
                                    if (i == 50) {
                                        return 33;
                                    } else {
                                        return 88;
                                    }
                                }
                            } else {
                                if (i <= 53) {
                                    if (i == 52) {
                                        return 237;
                                    } else {
                                        return 149;
                                    }
                                } else {
                                    if (i == 54) {
                                        return 56;
                                    } else {
                                        return 87;
                                    }
                                }
                            }
                        } else {
                            if (i <= 59) {
                                if (i <= 57) {
                                    if (i == 56) {
                                        return 174;
                                    } else {
                                        return 20;
                                    }
                                } else {
                                    if (i == 58) {
                                        return 125;
                                    } else {
                                        return 136;
                                    }
                                }
                            } else {
                                if (i <= 61) {
                                    if (i == 60) {
                                        return 171;
                                    } else {
                                        return 168;
                                    }
                                } else {
                                    if (i == 62) {
                                        return 68;
                                    } else {
                                        return 175;
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                if (i <= 95) {
                    if (i <= 79) {
                        if (i <= 71) {
                            if (i <= 67) {
                                if (i <= 65) {
                                    if (i == 64) {
                                        return 74;
                                    } else {
                                        return 165;
                                    }
                                } else {
                                    if (i == 66) {
                                        return 71;
                                    } else {
                                        return 134;
                                    }
                                }
                            } else {
                                if (i <= 69) {
                                    if (i == 68) {
                                        return 139;
                                    } else {
                                        return 48;
                                    }
                                } else {
                                    if (i == 70) {
                                        return 27;
                                    } else {
                                        return 166;
                                    }
                                }
                            }
                        } else {
                            if (i <= 75) {
                                if (i <= 73) {
                                    if (i == 72) {
                                        return 77;
                                    } else {
                                        return 146;
                                    }
                                } else {
                                    if (i == 74) {
                                        return 158;
                                    } else {
                                        return 231;
                                    }
                                }
                            } else {
                                if (i <= 77) {
                                    if (i == 76) {
                                        return 83;
                                    } else {
                                        return 111;
                                    }
                                } else {
                                    if (i == 78) {
                                        return 229;
                                    } else {
                                        return 122;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 87) {
                            if (i <= 83) {
                                if (i <= 81) {
                                    if (i == 80) {
                                        return 60;
                                    } else {
                                        return 211;
                                    }
                                } else {
                                    if (i == 82) {
                                        return 133;
                                    } else {
                                        return 230;
                                    }
                                }
                            } else {
                                if (i <= 85) {
                                    if (i == 84) {
                                        return 220;
                                    } else {
                                        return 105;
                                    }
                                } else {
                                    if (i == 86) {
                                        return 92;
                                    } else {
                                        return 41;
                                    }
                                }
                            }
                        } else {
                            if (i <= 91) {
                                if (i <= 89) {
                                    if (i == 88) {
                                        return 55;
                                    } else {
                                        return 46;
                                    }
                                } else {
                                    if (i == 90) {
                                        return 245;
                                    } else {
                                        return 40;
                                    }
                                }
                            } else {
                                if (i <= 93) {
                                    if (i == 92) {
                                        return 244;
                                    } else {
                                        return 102;
                                    }
                                } else {
                                    if (i == 94) {
                                        return 143;
                                    } else {
                                        return 54;
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 111) {
                        if (i <= 103) {
                            if (i <= 99) {
                                if (i <= 97) {
                                    if (i == 96) {
                                        return 65;
                                    } else {
                                        return 25;
                                    }
                                } else {
                                    if (i == 98) {
                                        return 63;
                                    } else {
                                        return 161;
                                    }
                                }
                            } else {
                                if (i <= 101) {
                                    if (i == 100) {
                                        return 1;
                                    } else {
                                        return 216;
                                    }
                                } else {
                                    if (i == 102) {
                                        return 80;
                                    } else {
                                        return 73;
                                    }
                                }
                            }
                        } else {
                            if (i <= 107) {
                                if (i <= 105) {
                                    if (i == 104) {
                                        return 209;
                                    } else {
                                        return 76;
                                    }
                                } else {
                                    if (i == 106) {
                                        return 132;
                                    } else {
                                        return 187;
                                    }
                                }
                            } else {
                                if (i <= 109) {
                                    if (i == 108) {
                                        return 208;
                                    } else {
                                        return 89;
                                    }
                                } else {
                                    if (i == 110) {
                                        return 18;
                                    } else {
                                        return 169;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 119) {
                            if (i <= 115) {
                                if (i <= 113) {
                                    if (i == 112) {
                                        return 200;
                                    } else {
                                        return 196;
                                    }
                                } else {
                                    if (i == 114) {
                                        return 135;
                                    } else {
                                        return 130;
                                    }
                                }
                            } else {
                                if (i <= 117) {
                                    if (i == 116) {
                                        return 116;
                                    } else {
                                        return 188;
                                    }
                                } else {
                                    if (i == 118) {
                                        return 159;
                                    } else {
                                        return 86;
                                    }
                                }
                            }
                        } else {
                            if (i <= 123) {
                                if (i <= 121) {
                                    if (i == 120) {
                                        return 164;
                                    } else {
                                        return 100;
                                    }
                                } else {
                                    if (i == 122) {
                                        return 109;
                                    } else {
                                        return 198;
                                    }
                                }
                            } else {
                                if (i <= 125) {
                                    if (i == 124) {
                                        return 173;
                                    } else {
                                        return 186;
                                    }
                                } else {
                                    if (i == 126) {
                                        return 3;
                                    } else {
                                        return 64;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if (i <= 191) {
                if (i <= 159) {
                    if (i <= 143) {
                        if (i <= 135) {
                            if (i <= 131) {
                                if (i <= 129) {
                                    if (i == 128) {
                                        return 52;
                                    } else {
                                        return 217;
                                    }
                                } else {
                                    if (i == 130) {
                                        return 226;
                                    } else {
                                        return 250;
                                    }
                                }
                            } else {
                                if (i <= 133) {
                                    if (i == 132) {
                                        return 124;
                                    } else {
                                        return 123;
                                    }
                                } else {
                                    if (i == 134) {
                                        return 5;
                                    } else {
                                        return 202;
                                    }
                                }
                            }
                        } else {
                            if (i <= 139) {
                                if (i <= 137) {
                                    if (i == 136) {
                                        return 38;
                                    } else {
                                        return 147;
                                    }
                                } else {
                                    if (i == 138) {
                                        return 118;
                                    } else {
                                        return 126;
                                    }
                                }
                            } else {
                                if (i <= 141) {
                                    if (i == 140) {
                                        return 255;
                                    } else {
                                        return 82;
                                    }
                                } else {
                                    if (i == 142) {
                                        return 85;
                                    } else {
                                        return 212;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 151) {
                            if (i <= 147) {
                                if (i <= 145) {
                                    if (i == 144) {
                                        return 207;
                                    } else {
                                        return 206;
                                    }
                                } else {
                                    if (i == 146) {
                                        return 59;
                                    } else {
                                        return 227;
                                    }
                                }
                            } else {
                                if (i <= 149) {
                                    if (i == 148) {
                                        return 47;
                                    } else {
                                        return 16;
                                    }
                                } else {
                                    if (i == 150) {
                                        return 58;
                                    } else {
                                        return 17;
                                    }
                                }
                            }
                        } else {
                            if (i <= 155) {
                                if (i <= 153) {
                                    if (i == 152) {
                                        return 182;
                                    } else {
                                        return 189;
                                    }
                                } else {
                                    if (i == 154) {
                                        return 28;
                                    } else {
                                        return 42;
                                    }
                                }
                            } else {
                                if (i <= 157) {
                                    if (i == 156) {
                                        return 223;
                                    } else {
                                        return 183;
                                    }
                                } else {
                                    if (i == 158) {
                                        return 170;
                                    } else {
                                        return 213;
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 175) {
                        if (i <= 167) {
                            if (i <= 163) {
                                if (i <= 161) {
                                    if (i == 160) {
                                        return 119;
                                    } else {
                                        return 248;
                                    }
                                } else {
                                    if (i == 162) {
                                        return 152;
                                    } else {
                                        return 2;
                                    }
                                }
                            } else {
                                if (i <= 165) {
                                    if (i == 164) {
                                        return 44;
                                    } else {
                                        return 154;
                                    }
                                } else {
                                    if (i == 166) {
                                        return 163;
                                    } else {
                                        return 70;
                                    }
                                }
                            }
                        } else {
                            if (i <= 171) {
                                if (i <= 169) {
                                    if (i == 168) {
                                        return 221;
                                    } else {
                                        return 153;
                                    }
                                } else {
                                    if (i == 170) {
                                        return 101;
                                    } else {
                                        return 155;
                                    }
                                }
                            } else {
                                if (i <= 173) {
                                    if (i == 172) {
                                        return 167;
                                    } else {
                                        return 43;
                                    }
                                } else {
                                    if (i == 174) {
                                        return 172;
                                    } else {
                                        return 9;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 183) {
                            if (i <= 179) {
                                if (i <= 177) {
                                    if (i == 176) {
                                        return 129;
                                    } else {
                                        return 22;
                                    }
                                } else {
                                    if (i == 178) {
                                        return 39;
                                    } else {
                                        return 253;
                                    }
                                }
                            } else {
                                if (i <= 181) {
                                    if (i == 180) {
                                        return 19;
                                    } else {
                                        return 98;
                                    }
                                } else {
                                    if (i == 182) {
                                        return 108;
                                    } else {
                                        return 110;
                                    }
                                }
                            }
                        } else {
                            if (i <= 187) {
                                if (i <= 185) {
                                    if (i == 184) {
                                        return 79;
                                    } else {
                                        return 113;
                                    }
                                } else {
                                    if (i == 186) {
                                        return 224;
                                    } else {
                                        return 232;
                                    }
                                }
                            } else {
                                if (i <= 189) {
                                    if (i == 188) {
                                        return 178;
                                    } else {
                                        return 185;
                                    }
                                } else {
                                    if (i == 190) {
                                        return 112;
                                    } else {
                                        return 104;
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                if (i <= 223) {
                    if (i <= 207) {
                        if (i <= 199) {
                            if (i <= 195) {
                                if (i <= 193) {
                                    if (i == 192) {
                                        return 218;
                                    } else {
                                        return 246;
                                    }
                                } else {
                                    if (i == 194) {
                                        return 97;
                                    } else {
                                        return 228;
                                    }
                                }
                            } else {
                                if (i <= 197) {
                                    if (i == 196) {
                                        return 251;
                                    } else {
                                        return 34;
                                    }
                                } else {
                                    if (i == 198) {
                                        return 242;
                                    } else {
                                        return 193;
                                    }
                                }
                            }
                        } else {
                            if (i <= 203) {
                                if (i <= 201) {
                                    if (i == 200) {
                                        return 238;
                                    } else {
                                        return 210;
                                    }
                                } else {
                                    if (i == 202) {
                                        return 144;
                                    } else {
                                        return 12;
                                    }
                                }
                            } else {
                                if (i <= 205) {
                                    if (i == 204) {
                                        return 191;
                                    } else {
                                        return 179;
                                    }
                                } else {
                                    if (i == 206) {
                                        return 162;
                                    } else {
                                        return 241;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 215) {
                            if (i <= 211) {
                                if (i <= 209) {
                                    if (i == 208) {
                                        return 81;
                                    } else {
                                        return 51;
                                    }
                                } else {
                                    if (i == 210) {
                                        return 145;
                                    } else {
                                        return 235;
                                    }
                                }
                            } else {
                                if (i <= 213) {
                                    if (i == 212) {
                                        return 249;
                                    } else {
                                        return 14;
                                    }
                                } else {
                                    if (i == 214) {
                                        return 239;
                                    } else {
                                        return 107;
                                    }
                                }
                            }
                        } else {
                            if (i <= 219) {
                                if (i <= 217) {
                                    if (i == 216) {
                                        return 49;
                                    } else {
                                        return 192;
                                    }
                                } else {
                                    if (i == 218) {
                                        return 214;
                                    } else {
                                        return 31;
                                    }
                                }
                            } else {
                                if (i <= 221) {
                                    if (i == 220) {
                                        return 181;
                                    } else {
                                        return 199;
                                    }
                                } else {
                                    if (i == 222) {
                                        return 106;
                                    } else {
                                        return 157;
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 239) {
                        if (i <= 231) {
                            if (i <= 227) {
                                if (i <= 225) {
                                    if (i == 224) {
                                        return 184;
                                    } else {
                                        return 84;
                                    }
                                } else {
                                    if (i == 226) {
                                        return 204;
                                    } else {
                                        return 176;
                                    }
                                }
                            } else {
                                if (i <= 229) {
                                    if (i == 228) {
                                        return 115;
                                    } else {
                                        return 121;
                                    }
                                } else {
                                    if (i == 230) {
                                        return 50;
                                    } else {
                                        return 45;
                                    }
                                }
                            }
                        } else {
                            if (i <= 235) {
                                if (i <= 233) {
                                    if (i == 232) {
                                        return 127;
                                    } else {
                                        return 4;
                                    }
                                } else {
                                    if (i == 234) {
                                        return 150;
                                    } else {
                                        return 254;
                                    }
                                }
                            } else {
                                if (i <= 237) {
                                    if (i == 236) {
                                        return 138;
                                    } else {
                                        return 236;
                                    }
                                } else {
                                    if (i == 238) {
                                        return 205;
                                    } else {
                                        return 93;
                                    }
                                }
                            }
                        }
                    } else {
                        if (i <= 247) {
                            if (i <= 243) {
                                if (i <= 241) {
                                    if (i == 240) {
                                        return 222;
                                    } else {
                                        return 114;
                                    }
                                } else {
                                    if (i == 242) {
                                        return 67;
                                    } else {
                                        return 29;
                                    }
                                }
                            } else {
                                if (i <= 245) {
                                    if (i == 244) {
                                        return 24;
                                    } else {
                                        return 72;
                                    }
                                } else {
                                    if (i == 246) {
                                        return 243;
                                    } else {
                                        return 141;
                                    }
                                }
                            }
                        } else {
                            if (i <= 251) {
                                if (i <= 249) {
                                    if (i == 248) {
                                        return 128;
                                    } else {
                                        return 195;
                                    }
                                } else {
                                    if (i == 250) {
                                        return 78;
                                    } else {
                                        return 66;
                                    }
                                }
                            } else {
                                if (i <= 253) {
                                    if (i == 252) {
                                        return 215;
                                    } else {
                                        return 61;
                                    }
                                } else {
                                    if (i == 254) {
                                        return 156;
                                    } else {
                                        return 180;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * @notice Gets a value in the fade table.
     *
     * @param i the index in the fade table.
     *
     * @dev The values from the table are mapped out into a binary tree for faster lookups.
     *      Looking up any value in the table in this implementation is is O(8), in
     *      the implementation of sequential if statements it is O(256).
     *
     * @dev The body of this function is autogenerated. Check out the 'gen-ftable' script.
     */
    function ftable(int256 i) internal pure returns (int256) {
        if (i <= 127) {
            if (i <= 63) {
                if (i <= 31) {
                    if (i <= 15) {
                        if (i <= 7) {
                            if (i <= 3) {
                                if (i <= 1) {
                                    if (i == 0) { return 0; } else { return 0; }
                                } else {
                                    if (i == 2) { return 0; } else { return 0; }
                                }
                            } else {
                                if (i <= 5) {
                                    if (i == 4) { return 0; } else { return 0; }
                                } else {
                                    if (i == 6) { return 0; } else { return 1; }
                                }
                            }
                        } else {
                            if (i <= 11) {
                                if (i <= 9) {
                                    if (i == 8) { return 4097; } else { return 4098; }
                                } else {
                                    if (i == 10) { return 8195; } else { return 12291; }
                                }
                            } else {
                                if (i <= 13) {
                                    if (i == 12) { return 12292; } else { return 16390; }
                                } else {
                                    if (i == 14) { return 24583; } else { return 28681; }
                                }
                            }
                        }
                    } else {
                        if (i <= 23) {
                            if (i <= 19) {
                                if (i <= 17) {
                                    if (i == 16) { return 36874; } else { return 40972; }
                                } else {
                                    if (i == 18) { return 49166; } else { return 57361; }
                                }
                            } else {
                                if (i <= 21) {
                                    if (i == 20) { return 69651; } else { return 77846; }
                                } else {
                                    if (i == 22) { return 90137; } else { return 102429; }
                                }
                            }
                        } else {
                            if (i <= 27) {
                                if (i <= 25) {
                                    if (i == 24) { return 118816; } else { return 131108; }
                                } else {
                                    if (i == 26) { return 147496; } else { return 163885; }
                                }
                            } else {
                                if (i <= 29) {
                                    if (i == 28) { return 184369; } else { return 200758; }
                                } else {
                                    if (i == 30) { return 221244; } else { return 245825; }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 47) {
                        if (i <= 39) {
                            if (i <= 35) {
                                if (i <= 33) {
                                    if (i == 32) { return 266311; } else { return 290893; }
                                } else {
                                    if (i == 34) { return 315476; } else { return 344155; }
                                }
                            } else {
                                if (i <= 37) {
                                    if (i == 36) { return 372834; } else { return 401513; }
                                } else {
                                    if (i == 38) { return 430193; } else { return 462969; }
                                }
                            }
                        } else {
                            if (i <= 43) {
                                if (i <= 41) {
                                    if (i == 40) { return 495746; } else { return 532619; }
                                } else {
                                    if (i == 42) { return 569492; } else { return 606366; }
                                }
                            } else {
                                if (i <= 45) {
                                    if (i == 44) { return 647335; } else { return 684210; }
                                } else {
                                    if (i == 46) { return 729276; } else { return 770247; }
                                }
                            }
                        }
                    } else {
                        if (i <= 55) {
                            if (i <= 51) {
                                if (i <= 49) {
                                    if (i == 48) { return 815315; } else { return 864478; }
                                } else {
                                    if (i == 50) { return 909546; } else { return 958711; }
                                }
                            } else {
                                if (i <= 53) {
                                    if (i == 52) { return 1011971; } else { return 1061137; }
                                } else {
                                    if (i == 54) { return 1118494; } else { return 1171756; }
                                }
                            }
                        } else {
                            if (i <= 59) {
                                if (i <= 57) {
                                    if (i == 56) { return 1229114; } else { return 1286473; }
                                } else {
                                    if (i == 58) { return 1347928; } else { return 1409383; }
                                }
                            } else {
                                if (i <= 61) {
                                    if (i == 60) { return 1470838; } else { return 1532294; }
                                } else {
                                    if (i == 62) { return 1597847; } else { return 1667496; }
                                }
                            }
                        }
                    }
                }
            } else {
                if (i <= 95) {
                    if (i <= 79) {
                        if (i <= 71) {
                            if (i <= 67) {
                                if (i <= 65) {
                                    if (i == 64) { return 1737145; } else { return 1806794; }
                                } else {
                                    if (i == 66) { return 1876444; } else { return 1950190; }
                                }
                            } else {
                                if (i <= 69) {
                                    if (i == 68) { return 2023936; } else { return 2097683; }
                                } else {
                                    if (i == 70) { return 2175526; } else { return 2253370; }
                                }
                            }
                        } else {
                            if (i <= 75) {
                                if (i <= 73) {
                                    if (i == 72) { return 2335309; } else { return 2413153; }
                                } else {
                                    if (i == 74) { return 2495094; } else { return 2581131; }
                                }
                            } else {
                                if (i <= 77) {
                                    if (i == 76) { return 2667168; } else { return 2753205; }
                                } else {
                                    if (i == 78) { return 2839243; } else { return 2929377; }
                                }
                            }
                        }
                    } else {
                        if (i <= 87) {
                            if (i <= 83) {
                                if (i <= 81) {
                                    if (i == 80) { return 3019511; } else { return 3109646; }
                                } else {
                                    if (i == 82) { return 3203877; } else { return 3298108; }
                                }
                            } else {
                                if (i <= 85) {
                                    if (i == 84) { return 3392339; } else { return 3486571; }
                                } else {
                                    if (i == 86) { return 3584899; } else { return 3683227; }
                                }
                            }
                        } else {
                            if (i <= 91) {
                                if (i <= 89) {
                                    if (i == 88) { return 3781556; } else { return 3883981; }
                                } else {
                                    if (i == 90) { return 3986406; } else { return 4088831; }
                                }
                            } else {
                                if (i <= 93) {
                                    if (i == 92) { return 4191257; } else { return 4297778; }
                                } else {
                                    if (i == 94) { return 4400204; } else { return 4506727; }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 111) {
                        if (i <= 103) {
                            if (i <= 99) {
                                if (i <= 97) {
                                    if (i == 96) { return 4617345; } else { return 4723868; }
                                } else {
                                    if (i == 98) { return 4834487; } else { return 4945106; }
                                }
                            } else {
                                if (i <= 101) {
                                    if (i == 100) { return 5055725; } else { return 5166345; }
                                } else {
                                    if (i == 102) { return 5281060; } else { return 5391680; }
                                }
                            }
                        } else {
                            if (i <= 107) {
                                if (i <= 105) {
                                    if (i == 104) { return 5506396; } else { return 5621112; }
                                } else {
                                    if (i == 106) { return 5735829; } else { return 5854641; }
                                }
                            } else {
                                if (i <= 109) {
                                    if (i == 108) { return 5969358; } else { return 6088171; }
                                } else {
                                    if (i == 110) { return 6206983; } else { return 6321700; }
                                }
                            }
                        }
                    } else {
                        if (i <= 119) {
                            if (i <= 115) {
                                if (i <= 113) {
                                    if (i == 112) { return 6440514; } else { return 6563423; }
                                } else {
                                    if (i == 114) { return 6682236; } else { return 6801050; }
                                }
                            } else {
                                if (i <= 117) {
                                    if (i == 116) { return 6923959; } else { return 7042773; }
                                } else {
                                    if (i == 118) { return 7165682; } else { return 7284496; }
                                }
                            }
                        } else {
                            if (i <= 123) {
                                if (i <= 121) {
                                    if (i == 120) { return 7407406; } else { return 7530316; }
                                } else {
                                    if (i == 122) { return 7653226; } else { return 7776136; }
                                }
                            } else {
                                if (i <= 125) {
                                    if (i == 124) { return 7899046; } else { return 8021956; }
                                } else {
                                    if (i == 126) { return 8144866; } else { return 8267776; }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if (i <= 191) {
                if (i <= 159) {
                    if (i <= 143) {
                        if (i <= 135) {
                            if (i <= 131) {
                                if (i <= 129) {
                                    if (i == 128) { return 8390685; } else { return 8509499; }
                                } else {
                                    if (i == 130) { return 8632409; } else { return 8755319; }
                                }
                            } else {
                                if (i <= 133) {
                                    if (i == 132) { return 8878229; } else { return 9001139; }
                                } else {
                                    if (i == 134) { return 9124049; } else { return 9246959; }
                                }
                            }
                        } else {
                            if (i <= 139) {
                                if (i <= 137) {
                                    if (i == 136) { return 9369869; } else { return 9492778; }
                                } else {
                                    if (i == 138) { return 9611592; } else { return 9734501; }
                                }
                            } else {
                                if (i <= 141) {
                                    if (i == 140) { return 9853315; } else { return 9976224; }
                                } else {
                                    if (i == 142) { return 10095037; } else { return 10213851; }
                                }
                            }
                        }
                    } else {
                        if (i <= 151) {
                            if (i <= 147) {
                                if (i <= 145) {
                                    if (i == 144) { return 10336760; } else { return 10455572; }
                                } else {
                                    if (i == 146) { return 10570289; } else { return 10689102; }
                                }
                            } else {
                                if (i <= 149) {
                                    if (i == 148) { return 10807914; } else { return 10922631; }
                                } else {
                                    if (i == 150) { return 11041443; } else { return 11156159; }
                                }
                            }
                        } else {
                            if (i <= 155) {
                                if (i <= 153) {
                                    if (i == 152) { return 11270875; } else { return 11385590; }
                                } else {
                                    if (i == 154) { return 11496210; } else { return 11610925; }
                                }
                            } else {
                                if (i <= 157) {
                                    if (i == 156) { return 11721544; } else { return 11832163; }
                                } else {
                                    if (i == 158) { return 11942782; } else { return 12053400; }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 175) {
                        if (i <= 167) {
                            if (i <= 163) {
                                if (i <= 161) {
                                    if (i == 160) { return 12159923; } else { return 12270541; }
                                } else {
                                    if (i == 162) { return 12377062; } else { return 12479488; }
                                }
                            } else {
                                if (i <= 165) {
                                    if (i == 164) { return 12586009; } else { return 12688434; }
                                } else {
                                    if (i == 166) { return 12790859; } else { return 12893284; }
                                }
                            }
                        } else {
                            if (i <= 171) {
                                if (i <= 169) {
                                    if (i == 168) { return 12995708; } else { return 13094036; }
                                } else {
                                    if (i == 170) { return 13192364; } else { return 13290691; }
                                }
                            } else {
                                if (i <= 173) {
                                    if (i == 172) { return 13384922; } else { return 13479153; }
                                } else {
                                    if (i == 174) { return 13573384; } else { return 13667614; }
                                }
                            }
                        }
                    } else {
                        if (i <= 183) {
                            if (i <= 179) {
                                if (i <= 177) {
                                    if (i == 176) { return 13757748; } else { return 13847882; }
                                } else {
                                    if (i == 178) { return 13938015; } else { return 14024052; }
                                }
                            } else {
                                if (i <= 181) {
                                    if (i == 180) { return 14110089; } else { return 14196126; }
                                } else {
                                    if (i == 182) { return 14282162; } else { return 14364101; }
                                }
                            }
                        } else {
                            if (i <= 187) {
                                if (i <= 185) {
                                    if (i == 184) { return 14441945; } else { return 14523884; }
                                } else {
                                    if (i == 186) { return 14601727; } else { return 14679569; }
                                }
                            } else {
                                if (i <= 189) {
                                    if (i == 188) { return 14753315; } else { return 14827061; }
                                } else {
                                    if (i == 190) { return 14900806; } else { return 14970456; }
                                }
                            }
                        }
                    }
                }
            } else {
                if (i <= 223) {
                    if (i <= 207) {
                        if (i <= 199) {
                            if (i <= 195) {
                                if (i <= 193) {
                                    if (i == 192) { return 15044200; } else { return 15109753; }
                                } else {
                                    if (i == 194) { return 15179401; } else { return 15244952; }
                                }
                            } else {
                                if (i <= 197) {
                                    if (i == 196) { return 15306407; } else { return 15367862; }
                                } else {
                                    if (i == 198) { return 15429317; } else { return 15490771; }
                                }
                            }
                        } else {
                            if (i <= 203) {
                                if (i <= 201) {
                                    if (i == 200) { return 15548129; } else { return 15605486; }
                                } else {
                                    if (i == 202) { return 15658748; } else { return 15716104; }
                                }
                            } else {
                                if (i <= 205) {
                                    if (i == 204) { return 15765269; } else { return 15818529; }
                                } else {
                                    if (i == 206) { return 15867692; } else { return 15912760; }
                                }
                            }
                        }
                    } else {
                        if (i <= 215) {
                            if (i <= 211) {
                                if (i <= 209) {
                                    if (i == 208) { return 15961923; } else { return 16006989; }
                                } else {
                                    if (i == 210) { return 16047960; } else { return 16093025; }
                                }
                            } else {
                                if (i <= 213) {
                                    if (i == 212) { return 16129899; } else { return 16170868; }
                                } else {
                                    if (i == 214) { return 16207741; } else { return 16244614; }
                                }
                            }
                        } else {
                            if (i <= 219) {
                                if (i <= 217) {
                                    if (i == 216) { return 16281486; } else { return 16314262; }
                                } else {
                                    if (i == 218) { return 16347037; } else { return 16375716; }
                                }
                            } else {
                                if (i <= 221) {
                                    if (i == 220) { return 16404395; } else { return 16433074; }
                                } else {
                                    if (i == 222) { return 16461752; } else { return 16486334; }
                                }
                            }
                        }
                    }
                } else {
                    if (i <= 239) {
                        if (i <= 231) {
                            if (i <= 227) {
                                if (i <= 225) {
                                    if (i == 224) { return 16510915; } else { return 16531401; }
                                } else {
                                    if (i == 226) { return 16555982; } else { return 16576466; }
                                }
                            } else {
                                if (i <= 229) {
                                    if (i == 228) { return 16592855; } else { return 16613339; }
                                } else {
                                    if (i == 230) { return 16629727; } else { return 16646114; }
                                }
                            }
                        } else {
                            if (i <= 235) {
                                if (i <= 233) {
                                    if (i == 232) { return 16658406; } else { return 16674793; }
                                } else {
                                    if (i == 234) { return 16687084; } else { return 16699374; }
                                }
                            } else {
                                if (i <= 237) {
                                    if (i == 236) { return 16707569; } else { return 16719859; }
                                } else {
                                    if (i == 238) { return 16728053; } else { return 16736246; }
                                }
                            }
                        }
                    } else {
                        if (i <= 247) {
                            if (i <= 243) {
                                if (i <= 241) {
                                    if (i == 240) { return 16740344; } else { return 16748537; }
                                } else {
                                    if (i == 242) { return 16752635; } else { return 16760828; }
                                }
                            } else {
                                if (i <= 245) {
                                    if (i == 244) { return 16764924; } else { return 16764925; }
                                } else {
                                    if (i == 246) { return 16769022; } else { return 16773118; }
                                }
                            }
                        } else {
                            if (i <= 251) {
                                if (i <= 249) {
                                    if (i == 248) { return 16773119; } else { return 16777215; }
                                } else {
                                    if (i == 250) { return 16777215; } else { return 16777215; }
                                }
                            } else {
                                if (i <= 253) {
                                    if (i == 252) { return 16777215; } else { return 16777215; }
                                } else {
                                    if (i == 254) { return 16777215; } else { return 16777215; }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}