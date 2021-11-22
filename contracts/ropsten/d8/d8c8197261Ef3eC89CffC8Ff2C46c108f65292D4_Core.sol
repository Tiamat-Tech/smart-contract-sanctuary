pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Accounts.sol";
import "./interfaces/IStorage.sol";

contract Core is Initializable, OwnableUpgradeable {
       /// ** PUBLIC states **

    address public storage_;
    uint16 public constant MAX_COURSES_FOR_STUDENTS = 32;
    uint16 public constant MAX_COURSES_FOR_TEACHERS = 16;
    uint16 public constant MAX_STUDENTS_FOR_COURSE = 256;

    /// ** PRIVATE states **

    /// ** STRUCTS **

    /// ** EVENTS **

    event StudentCreated(uint256 studentID);

    event TeacherCreated(uint256 teacherID);

    event CourseCreated(uint256 courseID);

    event StudentInfo(
        uint256 id,
        string name,
        uint256 groupID,
        uint256 credentialID,
        address account,
        uint256[] courses
    );

    event TeacherInfo(
        uint256 id,
        string name,
        address account,
        uint256[] courses
    );

    event CourseInfo(
        uint256 id,
        string name,
        uint256[] students,
        uint256 teacher,
        uint256[] days_,
        uint256[] time_
    );

    event Marks(
        uint8[] marks
    );

    /// ** MODIFIERs **

    /// ** INITIALIZER **

    function initialize(address _storage) public virtual initializer {
        __Ownable_init();

        storage_ = _storage;
    }

    /// ** PUBLIC functions **

    // ** EXTERNAL functions **

    function addStudent(
        string memory _name,
        uint256 _groupID,
        uint256 _credentialID,
        address _account
    ) external onlyOwner {
        accounts.Student memory student = accounts.Student({
            name: _name,
            groupID: _groupID,
            credentialID: _credentialID,
            account: _account,
            courses: new uint256[](MAX_COURSES_FOR_STUDENTS)
        });

        uint256 studentID = IStorage(storage_).addStudent(student);

        emit StudentCreated(studentID);
    }

    function addTeacher(string memory _name, address _account)
        external
        onlyOwner
    {
        accounts.Teacher memory teacher = accounts.Teacher({
            name: _name,
            account: _account,
            courses: new uint256[](MAX_COURSES_FOR_TEACHERS)
        });

        uint256 teacherID = IStorage(storage_).addTeacher(teacher);

        emit TeacherCreated(teacherID);
    }

    function addCourse(string memory _name, uint256 _teacher)
        external
        onlyOwner
    {
        accounts.Course memory course = accounts.Course({
            name: _name,
            students: new uint256[](MAX_STUDENTS_FOR_COURSE),
            teacher: _teacher
        });

        uint256 courseID = IStorage(storage_).addCourse(course);

        emit CourseCreated(courseID);
    }

    function addStudentsToCourse(uint256[] memory students, uint256 courseID) external {
        accounts.Course memory course = IStorage(storage_).getCourse(courseID);
        accounts.Teacher memory teacher = IStorage(storage_).getTeacher(course.teacher);

        require(teacher.account == msg.sender || msg.sender == owner(),
            'Teacher only can add students to their own courses.');

        IStorage(storage_).addStudentsToCourse(courseID, students);
    }

    function addMark(uint256 courseID, uint256 studentID, uint8 mark) external {
        accounts.Course memory course = IStorage(storage_).getCourse(courseID);
        accounts.Teacher memory teacher = IStorage(storage_).getTeacher(course.teacher);

        require(teacher.account == msg.sender || msg.sender == owner(),
            'Teacher only can add marks to their own courses.');

        IStorage(storage_).addMark(courseID, studentID, mark);
    }

    function setScheduleForCourse(uint256 courseID, accounts.DateTime[] memory schedule) external onlyOwner {
        IStorage(storage_).setScheduleForCourse(courseID, schedule);
        // TODO: add event emitting
    }

    function getMarks(uint256 studentID, uint256 courseID) external {
        emit Marks(IStorage(storage_).getMarks(courseID, studentID));
    }

    function getStudent(uint256 studentID)
        external
    {
        accounts.Student memory student = IStorage(storage_).getStudent(studentID);

        emit StudentInfo(
            studentID,
            student.name,
            student.groupID,
            student.credentialID,
            student.account,
            student.courses
        );
    }

    function getTeacher(uint256 teacherID)
        external
    {
        accounts.Teacher memory teacher = IStorage(storage_).getTeacher(teacherID);

        emit TeacherInfo(
            teacherID,
            teacher.name,
            teacher.account,
            teacher.courses
        );
    }

    function getCourse(uint256 courseID)
        external
    {
        accounts.Course memory course = IStorage(storage_).getCourse(courseID);
        uint256[] memory days_;
        uint256[] memory time_;

        (days_, time_) = IStorage(storage_).getSchedule(courseID);

        emit CourseInfo(
            courseID,
            course.name,
            course.students,
            course.teacher,
            days_,
            time_
        );
    }

    /// ** INTERNAL functions **
}