pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import  "./interfaces/IStorage.sol";
import "./Accounts.sol";

contract Storage is Initializable, OwnableUpgradeable {
    /// ** PUBLIC states **

    address public core;
    uint16 public constant MAX_COURSES_FOR_STUDENTS = 32;
    uint16 public constant MAX_COURSES_FOR_TEACHERS = 16;
    uint16 public constant MAX_STUDENTS_FOR_COURSE = 256;

    /// ** PRIVATE states **

    mapping(uint256 => accounts.Student) internal students; // list of students, key is student's ID
    mapping(uint256 => accounts.Teacher) internal teachers; // list of teachers, key is teacher's ID
    mapping(uint256 => accounts.Course) internal courses; // list of courses, key is courseID
    mapping(uint256 => mapping(uint256 => uint8[])) internal marks; // courseID => studentID => array of marks
    mapping(uint256 => accounts.DateTime[]) schedule;

    uint256 lastCreatedStudentID;
    uint256 lastCreatedTeacherID;
    uint256 lastCreatedCourseID;

    /// ** STRUCTS **

    /// ** EVENTS **

    /// ** MODIFIERs **

    modifier onlyCore() {
        require(msg.sender == core, "Permission denied (not a core).");
        _;
    }

    /// ** INITIALIZER **

    function initialize() public virtual initializer {
        __Ownable_init();

        lastCreatedStudentID = 1;
        lastCreatedTeacherID = 1;
        lastCreatedCourseID = 1;
    }

    /// ** PUBLIC functions **

    // ** EXTERNAL functions **

    function setCore(address _core) external onlyOwner {
        core = _core;
    }

    function addStudent(
        accounts.Student memory student
    ) external onlyCore returns (uint256) {
        uint256 studentID = _getNewStudentID();
        students[studentID] = student;

        return studentID;
    }

    function addTeacher(accounts.Teacher memory teacher)
        external
        onlyCore
        returns (uint256)
    {
        uint256 teacherID = _getNewTeacherID();
        teachers[teacherID] = teacher;

        return teacherID;
    }

    function addCourse(accounts.Course memory course)
        external
        onlyCore
        returns (uint256)
    {
        uint256 courseID = _getNewCourseID();
        courses[courseID] = course;

        for (uint256 i = 0; i < MAX_COURSES_FOR_TEACHERS; i++)
        {
            if (teachers[course.teacher].courses[i] == 0)
            {
                teachers[course.teacher].courses[i] = courseID;
                break;
            }
        }

        return courseID;
    }

    function addStudentsToCourse(uint256 courseID, uint256[] memory students) external onlyCore {
        for (uint256 i = 0; i < MAX_STUDENTS_FOR_COURSE; i++)
        {
            if (courses[courseID].students[i] == 0)
            {
                for (uint256 j = 0; j < students.length; j++)
                {
                   courses[courseID].students[i + j] = students[j];
                }

                break;
            }
        }
    }

    function setScheduleForCourse(uint256 courseID, accounts.DateTime[] memory _schedule) external onlyCore {
        delete schedule[courseID];

        for (uint256 i = 0; i < _schedule.length; i++)
        {
            schedule[courseID].push(_schedule[i]);
        }
    }

    function addMark(uint256 courseID, uint256 studentID, uint8 mark) external onlyCore {
        marks[courseID][studentID].push(mark);
    }

    function getStudent(uint256 studentID)
        external
        view
        onlyCore
        returns (accounts.Student memory)
    {
        return students[studentID];
    }

    function getTeacher(uint256 teacherID)
        external
        view
        onlyCore
        returns (accounts.Teacher memory)
    {
        return teachers[teacherID];
    }

    function getCourse(uint256 courseID)
        external
        view
        onlyCore
        returns (accounts.Course memory)
    {
        return courses[courseID];
    }

    /// ** INTERNAL functions **

    function _getNewStudentID() internal returns (uint256) {
        return lastCreatedStudentID++;
    }

    function _getNewTeacherID() internal returns (uint256) {
        return lastCreatedTeacherID++;
    }

    function _getNewCourseID() internal returns (uint256) {
        return lastCreatedCourseID++;
    }
}