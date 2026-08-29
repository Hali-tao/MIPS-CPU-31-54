#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <fstream>
using namespace std;

int main(){
    string filenames = "1_addi 2_addiu 3_andi 4_ori 5_sltiu 6_lui 7_xori 8_slti 9_addu 10_and 11_beq 12_bne 13_j 14_jal 15_jr 16.26_lwsw 16.26_lwsw2 17_xor 18_nor 19_or 20_sll 21_sllv 22_sltu 23_sra 24_srl 25_subu 27_add 28_sub 29_slt 30_srlv 31_srav 32_clz 33_divu 35_jalr 36.39_lbsb 36.39_lbsb2 37_lbu 37_lbu2 38_lhu 38_lhu2 40.41_lhsh 40.41_lhsh2 42.45_mfc0mtc0 43.46_mfhi.mthi 44.47_mflo.mtlo 48_mult 49_multu 52_bgez 54_div";
    vector<string> v;
    stringstream ss(filenames);
    string token;
    while (ss >> token) {
        v.push_back(token);
    }
    
    int total = v.size();
    int cnt = 0;
    for(const string& filename : v){
        string demo_file = filename + ".result.txt";
        string tb_file  = filename + "_multiple_tb.txt";
        ifstream demo(demo_file);
        ifstream tb(tb_file);
        if(!demo){
            cout << demo_file << " not found!" << endl;
            continue;
        }
        if(!tb){
            cout << tb_file << " not found!" << endl;
            continue;
        }

        string line_demo, line_tb;
        int lineno = 0;
        bool failed = false;
        while (getline(demo, line_demo)) {
            lineno++;
            if (!getline(tb, line_tb)) {
                cout << filename << " compare failed at line " << lineno << " (tb file ended early)" << endl;
                failed = true;
                break;
            }
            if (line_demo != line_tb) {
                cout << filename << " compare failed at line " << lineno << endl;
                failed = true;
                break;
            }
        }

        if (!failed) {
            cout << filename << " compare passed" << endl;
            cnt++;
        }

        demo.close();
        tb.close();
    }
    cout << "Total tests: " << total << endl;
    cout << "Total passed: " << cnt << endl;
    return 0;
}